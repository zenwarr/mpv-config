local msg = require "mp.msg"
local utils = require "mp.utils"
local options = require "mp.options"

local o = {
    ffmpeg_path = "ffmpeg",
    target_dir = "~~/mpv_fragments"
}

options.read_options(o)

local cur_slice_start = nil
local cur_slice_end = nil
local copy_audio = true
local is_preview_mode = false
local is_rendering = false
local status_overlay = mp.create_osd_overlay('ass-events')

Command = { }

function Command:new(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.name = ""
    o.args = { "" }
    if name then
        o.name = name
        o.args[1] = name
    end
    return o
end
function Command:arg(...)
    for _, v in ipairs({ ... }) do
        self.args[#self.args + 1] = v
    end
    return self
end
function Command:as_str()
    return table.concat(self.args, " ")
end
function Command:run()
    local res, err = mp.command_native({
        name = "subprocess",
        args = self.args,
        capture_stdout = true,
        capture_stderr = true,
    })
    return res, err
end

local function timestamp(duration)
    local hours = math.floor(duration / 3600)
    local minutes = math.floor(duration % 3600 / 60)
    local seconds = duration % 60
    return string.format("%02d:%02d:%02.03f", hours, minutes, seconds)
end

local function osd(str)
    return mp.osd_message(str, 3)
end

local function get_outname(shift, endpos)
    local name = mp.get_property("media-title")
    name = string.format("%s_%s-%s.%s", name, timestamp(shift), timestamp(endpos), ".mp4")
    return name:gsub(":", "-")
end

local function replace_newline_with_spaces(str)
    return str:gsub("\r?\n", " ")
end

local function log_cmd_output(res)
    if res.stderr ~= "" or res.stdout ~= "" then
        msg.info("stderr: " .. (res.stderr:gsub("^%s*(.-)%s*$", "%1"))) -- trim stderr
        msg.info("stdout: " .. (res.stdout:gsub("^%s*(.-)%s*$", "%1"))) -- trim stdout
    end
end

local function cut()
    local inpath = mp.get_property("stream-open-filename")
    local outpath = utils.join_path(
            o.target_dir,
            get_outname(cur_slice_start, cur_slice_end)
    )
    local ua = mp.get_property('user-agent')
    local referer = mp.get_property('referrer')

    local audio_track_index = mp.get_property_native("current-tracks/audio/ff-index")
    local video_track_index = mp.get_property_native("current-tracks/video/ff-index")

    local cmds = Command:new(o.ffmpeg_path)
                        :arg("-v", "warning")
                        :arg("-accurate_seek")
    if ua and ua ~= '' and ua ~= 'libmpv' then
        cmds:arg('-user_agent', ua)
    end
    if referer and referer ~= '' then
        cmds:arg('-referer', referer)
    end
    cmds:arg("-ss", tostring(cur_slice_start))
        :arg("-to", tostring(cur_slice_end))
        :arg("-i", inpath)
        :arg(not copy_audio and "-an" or nil)
        :arg("-map_chapters", "-1")
        :arg("-map", string.format("0:%d", video_track_index))
        :arg("-map", string.format("0:%d", audio_track_index))
        :arg(outpath)
    msg.info("Run commands: " .. cmds:as_str())

    local res, err = cmds:run()

    if err then
        msg.error(utils.to_string(err))
        status_overlay.data = "{\\a0\\fs20\\c&HFF&}Error: " .. utils.to_string(err)
    elseif res.status ~= 0 then
        msg.error("ffmpeg exited with status " .. res.status)
        log_cmd_output(res)
        status_overlay.data = "{\\a0\\fs20\\c&HFF&}Error: " .. replace_newline_with_spaces(res.stderr)
    else
        log_cmd_output(res)
        status_overlay.data = "{\\a0\\fs20\\c&HFF00&}Encoding completed (saved to " .. outpath .. ")"
    end

    status_overlay:update()

    mp.add_timeout(2, function()
        if status_overlay ~= nil then
            status_overlay:remove()
        end
    end)
end

local function update_osd()
    if cur_slice_start == nil and cur_slice_end == nil then
        status_overlay:remove()
        return
    end

    local slice_start = (cur_slice_start and timestamp(cur_slice_start)) or "<not set>"
    local slice_end = (cur_slice_end and timestamp(cur_slice_end)) or "<not set>"

    local cur_slice_offset = 0
    local offset_percent = nil

    if is_preview_mode and cur_slice_start ~= nil and cur_slice_end ~= nil then
        cur_slice_offset = mp.get_property_native("time-pos") - cur_slice_start
        offset_percent = ((cur_slice_offset + 0.0) / (cur_slice_end - cur_slice_start)) * 100
        offset_percent = string.format("%.1f", offset_percent)
    end

    status_overlay.data = ""

    if is_preview_mode and offset_percent ~= nil then
        status_overlay.data = status_overlay.data .. "{\\a0\\fs20}"
        status_overlay.data = status_overlay.data .. "Preview (p again to stop): " .. offset_percent .. "%\n"
    end

    status_overlay.data = status_overlay.data .. "{\\a0\\fs20}"
    status_overlay.data = status_overlay.data .. "Fragment: " .. slice_start .. " - " .. slice_end .. "\n"

    status_overlay.data = status_overlay.data .. "{\\a0\\fs20}"
    status_overlay.data = status_overlay.data .. "Press c to set start, C to set end, ENTER to cut, ESC to cancel, p to preview, HOME to jump to slice start, END to jump to the end"

    status_overlay:update()
end

local function slice_set_start()
    local pos, err = mp.get_property_number("time-pos")
    if not pos then
        osd("Failed to get timestamp")
        msg.error("Failed to get timestamp: " .. err)
        return
    end

    if cur_slice_end ~= nil and pos > cur_slice_end then
        osd("Start timestamp must be less than end timestamp")
        return
    end

    cur_slice_start = pos
    update_osd()
end

local function slice_set_end()
    local pos, err = mp.get_property_number("time-pos")
    if not pos then
        osd("Failed to get timestamp")
        msg.error("Failed to get timestamp: " .. err)
        return
    end

    if cur_slice_start ~= nil and pos < cur_slice_start then
        osd("End timestamp must be greater than start timestamp")
        return
    end

    cur_slice_end = pos
    update_osd()
end

local function remove_bindings()
    mp.remove_key_binding("set_start")
    mp.remove_key_binding("set_end")
    mp.remove_key_binding("cut")
    mp.remove_key_binding("cancel")
    mp.remove_key_binding("preview")
    mp.remove_key_binding("jump_start")
    mp.remove_key_binding("jump_end")

    mp.set_property_native("ab-loop-a", nil)
    mp.set_property_native("ab-loop-b", nil)
end

local function slice_cancel()
    cur_slice_start = nil
    cur_slice_end = nil
    is_preview_mode = false
    is_rendering = false
    remove_bindings()
    update_osd()
end

local function slice_cut()
    if not cur_slice_start or not cur_slice_end then
        osd("Slice boundaries not set")
        return
    end

    is_rendering = true

    status_overlay.data = "{\\a0\\fs20}Encoding video fragment..."
    status_overlay:update()

    cut()
    cur_slice_start = nil
    cur_slice_end = nil
    is_preview_mode = false
    is_rendering = false
    remove_bindings()
end

local function stop_preview()
    if not is_preview_mode then
        return
    end

    is_preview_mode = false
    mp.set_property_native("ab-loop-a", nil)
    mp.set_property_native("ab-loop-b", nil)
    mp.set_property_native("pause", true)
    update_osd()
end

local function slice_preview()
    if is_preview_mode then
        stop_preview()
        return
    end

    if cur_slice_start == nil or cur_slice_end == nil then
        osd("Slice boundaries not set")
        return
    end

    is_preview_mode = true
    mp.set_property_native("ab-loop-a", cur_slice_start)
    mp.set_property_native("ab-loop-b", cur_slice_end)
    mp.set_property_native("time-pos", cur_slice_start)
    mp.set_property_native("pause", false)
end

local function slice_jump_start()
    if cur_slice_start == nil then
        osd("Slice start not set")
        return
    end

    stop_preview()
    mp.set_property_native("time-pos", cur_slice_start)
end

local function slice_jump_end()
    if cur_slice_end == nil then
        osd("Slice end not set")
        return
    end

    stop_preview()
    mp.set_property_native("time-pos", cur_slice_end)
end

local function set_bindings()
    mp.add_forced_key_binding("c", "set_start", slice_set_start)
    mp.add_forced_key_binding("C", "set_end", slice_set_end)
    mp.add_forced_key_binding("ENTER", "cut", slice_cut)
    mp.add_forced_key_binding("ESC", "cancel", slice_cancel)
    mp.add_forced_key_binding("p", "preview", slice_preview)
    mp.add_forced_key_binding("HOME", "jump_start", slice_jump_start)
    mp.add_forced_key_binding("END", "jump_end", slice_jump_end)
end

local function editor_start()
    print("editor_start")
    set_bindings()
    slice_set_start()
    update_osd()
end

o.target_dir = o.target_dir:gsub('"', "")
local file, _ = utils.file_info(mp.command_native({ "expand-path", o.target_dir }))
if not file then
    --create target_dir if it doesn't exist
    local savepath = mp.command_native({ "expand-path", o.target_dir })
    local is_windows = package.config:sub(1, 1) == "\\"
    local windows_args = { 'powershell', '-NoProfile', '-Command', 'mkdir', savepath }
    local unix_args = { 'mkdir', savepath }
    local args = is_windows and windows_args or unix_args
    local res = mp.command_native({ name = "subprocess", capture_stdout = true, playback_only = false, args = args })
    if res.status ~= 0 then
        msg.error("Failed to create target_dir save directory " .. savepath .. ". Error: " .. (res.error or "unknown"))
        return
    end
elseif not file.is_dir then
    osd("target_dir is a file")
    msg.warn(string.format("target_dir `%s` is a file", o.target_dir))
end
o.target_dir = mp.command_native({ "expand-path", o.target_dir })

mp.register_script_message("start", editor_start)

mp.observe_property("time-pos", "native", function()
    if not is_preview_mode then
        return
    end

    update_osd()
end)
