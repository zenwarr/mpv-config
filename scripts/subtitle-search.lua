--[[
Based on sub-search script by kelciour (https://github.com/kelciour/mpv-scripts/blob/master/sub-search.lua)

Differences from the original script:

- Searches in a subtitle file active as a primary subtitle instead of attempting to find subtitle files matching video name
- Outputs all search results in OSD list instead of jumping between them with a hotkey (the closest subtitle is selected by default)
- Supports searching unicode text (subtitles should be encoded as utf8, please re-encode your subtitles if you get no results searching for unicode text)
- Embedded console replaced with more recent variant from mpv sources (to support unicode input)
- Takes into account current `sub-delay` value
- Can search in embedded subtitles (requires ffmpeg to be installed to extract subtitles from video files)
- Can search subtitles for youtube videos (requires ffmpeg to be installed to fetch remote subtitles)
- Supports `.srt`, `.vtt` and `.sub` (microdvd) subtitle formats
- Can use special phrase "*" to show all subtitle lines
- Use `ctrl+shift+f` shortcut to show all subtitle lines simultaneously and dynamically highlight the current line
- Press `Ctrl+Shift+Enter` in result list to adjust `sub-delay` so that selected subtitle line is displayed at the current position

Requires `script-modules/utf8` repository, `script-modules/scroll-list.lua`, `script-modules/sha1.lua`, `script-modules/utf8_data.lua` and `script-modules/input-console.lua` to work.

You can clone `script-modules/utf8` repository with the following command (assuming you are in mpv config directory): `git clone git@github.com:Stepets/utf8.lua.git script-modules/utf8`

Usage:
    Press Ctrl + F, print something and press Enter.
Example:
    'You are playing Empire Strikes Back and press Ctrl+F, type "I am you father" + Enter
    and voilá, the scene pops up.'
--]]


package.path = package.path .. ";" .. mp.command_native({ "expand-path", "~~/script-modules/?.lua" })

local mp = require("mp")
local utils = require("mp.utils")
local msg = require("mp.msg")
local input_console = require("input-console")
local result_list = require("scroll-list")
local utf8 = require("utf8/init")
local utf8_data = require("utf8_data")
local sha1 = require("sha1")

utf8.config = {
    conversion = {
        uc_lc = utf8_data.utf8_uc_lc,
        lc_uc = utf8_data.utf8_lc_uc
    },
}

utf8:init()

table.insert(result_list.keybinds, {
    "ENTER", "jump_to_result", function()
        local selected_index = result_list.selected
        if selected_index == nil then
            return
        end

        local selected = result_list.list[selected_index]
        mp.commandv("seek", selected.time, "absolute+exact")
    end, {}
})
table.insert(result_list.keybinds, {
    "Ctrl+Shift+ENTER", "sync_to_result", function()
        local selected_index = result_list.selected
        if selected_index == nil then
            return
        end

        local selected = result_list.list[selected_index]
        local old_delay = mp.get_property_native("sub-delay")
        local delay = -(selected.original_time - mp.get_property_native("time-pos"))
        mp.set_property_native("sub-delay", delay)
    end, {}
})

function sub_time_to_seconds(time, sep)
    if time:match("%d%d:%d%d" .. sep .. "%d%d%d") then
        time = "00:" .. time
    end

    local major, minor = time:match("(%d%d:%d%d:%d%d)" .. sep .. "(%d%d%d)")
    local hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

local subs_cache = {}

function open_file(path)
    local f, err = io.open(path, "r")
    if f and err == nil then
        return f
    end

    return nil
end

function is_supported_network_protocol(url)
    local protocols = { "http", "https" }

    for _, protocol in pairs(protocols) do
        if url:sub(1, #protocol + 3) == protocol .. "://" then
            return true
        end
    end

    return false
end

function get_sub_filename_async(track_name, on_done)
    local active_track = mp.get_property_native("current-tracks/" .. track_name)
    if active_track == nil then
        on_done(nil)
        return
    end

    local is_external = active_track.external
    local external_filename = active_track["external-filename"]

    -- youtube subtitles specified with edl format
    if is_external and external_filename and external_filename:sub(1, 6) == "edl://" then
        download_subtitle_async(external_filename:match("https://.*"), on_done)
        return
    end

    if is_external and external_filename and is_supported_network_protocol(external_filename) then
        download_subtitle_async(external_filename, on_done)
        return
    end

    if is_external and external_filename then
        on_done(external_filename)
        return
    end

    if is_external == false then
        extract_subtitle_track_async(active_track, on_done)
        return
    end

    on_done(nil)
end

function get_path_to_extract_sub(uniq_sub_id)
    local sub_filename = sha1.hex(uniq_sub_id)
    return utils.join_path(get_temp_dir(), "mpv-subtitle-search-extracted-" .. sub_filename .. ".srt")
end

function download_subtitle_async(url, on_done)
    local sub_path = get_path_to_extract_sub(mp.get_property_native("path") .. "#" .. url)

    if subs_cache[sub_path] then
        on_done(sub_path)
        return
    end

    local extract_overlay = mp.create_osd_overlay("ass-events")
    extract_overlay.data = "{\\a3\\fs20}Fetching remote subtitles, wait..."
    extract_overlay:update()

    mp.command_native_async({
        name = "subprocess",
        capture_stdout = true,
        args = { "ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", url, "-vn", "-an", "-c:s", "srt", sub_path }
    }, function(ok)
        if not ok then
            extract_overlay.data = "{\\a3\\fs20\\c&HFF&}Extraction failed"
            extract_overlay:update()

            mp.add_timeout(2, function()
                extract_overlay:remove()
            end)

            on_done(nil)
        else
            extract_overlay:remove()

            on_done(sub_path)
        end
    end)
end

function extract_subtitle_track_async(track, on_done)
    if track.external then
        on_done(nil)
        return
    end

    local video_file = mp.get_property_native("path")
    local working_dir = mp.get_property_native("working-directory")
    local full_path = utils.join_path(working_dir, video_file)

    local track_index = track["ff-index"]
    local sub_path = get_path_to_extract_sub(full_path .. "#" .. track_index)

    -- check if file already exists
    if open_file(sub_path) then
        msg.info("Reusing extracted subtitle track from " .. sub_path)

        on_done(sub_path)
        return
    end

    msg.info("Extracting embedded subtitle track to " .. sub_path)

    local extract_overlay = mp.create_osd_overlay("ass-events")
    extract_overlay.data = "{\\a3\\fs20}Extracting embedded subtitles, wait..."
    extract_overlay:update()

    mp.command_native_async({
        name = "subprocess",
        capture_stdout = true,
        args = { "ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", full_path, "-map", "0:" .. track_index, "-vn", "-an", "-c:s", "srt", sub_path }
    }, function(ok)
        if not ok then
            extract_overlay.data = "{\\a3\\fs20\\c&HFF&}Extraction failed"
            extract_overlay:update()

            mp.add_timeout(2, function()
                extract_overlay:remove()
            end)

            on_done(nil)
        else
            extract_overlay:remove()

            on_done(sub_path)
        end
    end)
end

function get_temp_dir()
    local temp_dir = os.getenv("TMPDIR")
    if temp_dir == nil then
        temp_dir = os.getenv("TEMP")
    end

    if temp_dir == nil then
        temp_dir = os.getenv("TMP")
    end

    if temp_dir == nil then
        temp_dir = "/tmp"
    end

    return temp_dir
end

function get_lines(input)
    local lines = {}

    local tail = 1
    for head = 1, #input do
        local ch = input:sub(head, head)
        if ch == "\n" then
            table.insert(lines, input:sub(tail, head - 1))
            tail = head + 1
        elseif head == #input then
            table.insert(lines, input:sub(tail, head))
        end
    end

    return lines
end

function trim(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

function parse_vtt_sub(data)
    local result = {}
    local state = "header"

    local cur_line = {}
    for _, line in ipairs(get_lines(data)) do
        line = trim(line)
        if state == "header" then
            if line == "" then
                state = "body"
            end
        elseif state == "body" then
            if line == "" then
                state = "header"
            elseif line:match("^NOTE") or line:match("^STYLE") then
                state = "comment"
            else
                local time_text = line:match("^(%d%d:%d%d:%d%d%.%d%d%d)") or line:match("^(%d%d:%d%d%.%d%d%d)")
                if time_text then
                    cur_line.time = sub_time_to_seconds(time_text, ".")
                    state = "waiting_text"
                else
                    state = "body"
                end
            end
        elseif state == "comment" then
            if #line == 0 then
                state = "body"
            end
        elseif state == "waiting_text" then
            if #line == 0 or line == nil then
                if cur_line.text ~= nil then
                    table.insert(result, cur_line)
                end

                cur_line = {}
                state = "body"
            else
                line = remove_tags(line)
                if cur_line.text then
                    cur_line.text = cur_line.text .. "\n" .. line
                else
                    cur_line.text = line
                end
            end
        end
    end

    return result
end

function remove_tags(text)
    function remove_tag(tag_to_remove)
        return string.gsub(text, "</?" .. tag_to_remove .. ">", "")
    end

    text = remove_tag("b")
    text = remove_tag("i")
    text = remove_tag("u")
    text = remove_tag("ruby")
    text = remove_tag("rt")

    -- remove class tag
    text = remove_tag("c")
    text = string.gsub(text, "<c.[^>]*>", "")

    -- remove voice tag
    text = remove_tag("v")
    text = string.gsub(text, "<v [^>]*>", "")

    -- remove karaoke karaoke tags
    text = string.gsub(text, "</?%d%d:%d%d.%d%d%d>", "")
    text = string.gsub(text, "</?%d%d:%d%d:%d%d.%d%d%d>", "")

    -- remove font tag
    text = string.gsub(text, '<font color="#?[%d%a]+">', "")
    text = string.gsub(text, '</font>', "")

    return text
end


-- detects only most common encodings
function get_encoding_from_bom(data)
    -- utf8
    local bom = data:sub(1, 3)
    if bom == "\xEF\xBB\xBF" then
        return "utf-8"
    end

    -- utf16
    bom = data:sub(1, 2)
    if bom == "\xFF\xFE" or bom == "\xFE\xFF" then
        return "utf-16"
    end

    -- utf32
    bom = data:sub(1, 4)
    if bom == "\xFF\xFE\x00\x00" or bom == "\x00\x00\xFE\xFF" then
        return "utf-32"
    end

    return nil
end

function is_microdvd_sub(data)
    return data:match("{%d+}{%d+}")
end

function parse_microdvd_sub(data)
    local result = {}
    local lines = get_lines(data)

    -- if the first line contains only number, it's a subtitle fps
    local subtitle_fps = tonumber(lines[1])
    if subtitle_fps == nil or subtitle_fps == 0 then
        subtitle_fps = mp.get_property_native("container-fps")
        if subtitle_fps == nil or subtitle_fps == 0 then
            subtitle_fps = 24
        end
    end

    msg.info("Using " .. subtitle_fps .. "fps for microdvd subtitle")

    for _, line in ipairs(lines) do
        local time_text = line:match("^{(%d+)}{(%d+)}")
        if time_text then
            local start_frame = tonumber(time_text:match("^(%d+)"))

            local text = line:match("^{%d+}{%d+}(.*)")
            text = text:gsub("|", " ")
            if text then
                table.insert(result, {
                    time = frame_to_secs(start_frame, subtitle_fps),
                    text = text
                })
            end
        end
    end

    return result
end

function frame_to_secs(frame, subtitle_fps)
    return frame / subtitle_fps
end

function parse_sub(data)
    bom_encoding = get_encoding_from_bom(data)
    if bom_encoding ~= nil then
        if bom_encoding == "utf-8" then
            data = data:sub(3)
        else
            local error_overlay = mp.create_osd_overlay("ass-events")
            error_overlay.data = "{\\a3\\fs20\\c&HFF&}Unsupported subtitle encoding: " .. bom_encoding .. ", please re-encode subtitle file to utf-8 to search"
            error_overlay:update()

            msg.error("Unsupported subtitle encoding: " .. bom_encoding .. ", please re-encode subtitle file to utf-8 to search")

            mp.add_timeout(10, function()
                error_overlay:remove()
            end)

            return {}
        end
    end

    data = string.gsub(data, "\r\n", "\n")

    if data:sub(1, 6) == "WEBVTT" then
        return parse_vtt_sub(data)
    end

    if is_microdvd_sub(data) then
        return parse_microdvd_sub(data)
    end

    local result = {}
    local state = "waiting_index"
    local cur_line = {}
    for _, line in ipairs(get_lines(data)) do
        line = trim(line)
        if state == "waiting_index" then
            if cur_line.text then
                table.insert(result, cur_line)
                cur_line = {}
            end

            if line:match("^%d+$") then
                state = "waiting_time"
            end
        elseif state == "waiting_time" then
            local time_text = line:match("^(%d%d:%d%d:%d%d,%d%d%d) ")
            if time_text then
                cur_line.time = sub_time_to_seconds(time_text, ",")
                state = "waiting_text"
            else
                state = "waiting_index"
            end
        elseif state == "waiting_text" then
            line = remove_tags(line)
            if #line == 0 then
                if cur_line.text then
                    table.insert(result, cur_line)
                end
                cur_line = {}
                state = "waiting_index"
            elseif cur_line.text then
                cur_line.text = cur_line.text .. " " .. line
            else
                cur_line.text = line
            end
        end
    end

    if cur_line.text then
        table.insert(result, cur_line)
    end

    return result
end

function load_sub(path, prefix)
    if not path then
        return nil
    end

    local cached = subs_cache[path]
    if cached then
        return cached
    end

    local f = open_file(path)
    if not f then
        return nil
    end

    local data = f:read("*all")
    f:close()

    local sub = {
        prefix = prefix,
        lines = parse_sub(data)
    }
    subs_cache[path] = sub
    return sub
end

function make_nocase_pattern(s)
    local result = ""
    for _, code in utf8.codes(s) do
        local c = utf8.char(code)
        result = result .. string.format("[%s%s]", utf8.lower(c), utf8.upper(c))
    end
    return result
end

-- highlight found text with colored text in ass syntax
function highlight_match(text, match_text, style_reset)
    local match_start, match_end = utf8.find(utf8.lower(text), utf8.lower(match_text))
    if match_start == nil then
        return text
    end

    local before = result_list.ass_escape(utf8.sub(text, 1, match_start - 1))
    local match = result_list.ass_escape(utf8.sub(text, match_start, match_end))
    local after = result_list.ass_escape(utf8.sub(text, match_end + 1))

    if style_reset == "" then
        style_reset = "{\\c&HFFFFFF&}"
    end

    return before .. "{\\c&HFF00&}" .. match .. style_reset .. after
end

function adjust_sub_time(time)
    local delay = mp.get_property_native("sub-delay")
    if delay == nil then
        return time
    end
    return time + delay
end

function divmod (a, b)
    return math.floor(a / b), a % b
end

function format_time(time)
    decimals = 3
    sep = "."
    local s = time
    local h, s = divmod(s, 60 * 60)
    local m, s = divmod(s, 60)

    local second_format = string.format("%%0%d.%df", 2 + (decimals > 0 and decimals + 1 or 0), decimals)

    return string.format("%02d" .. sep .. "%02d" .. sep .. second_format, h, m, s)
end

function get_subs_to_search_in_async(on_done)
    local result = {}

    get_sub_filename_async("sub", function(primary_filename)
        local sub = load_sub(primary_filename, "P")
        if sub then
            table.insert(result, sub)
        end

        get_sub_filename_async("sub2", function(secondary_filename)
            sub = load_sub(secondary_filename, "S")
            if sub then
                table.insert(result, sub)
            end

            on_done(result)
        end)
    end)
end

function update_search_results_async(query, live)
    get_subs_to_search_in_async(function(subs)
        if #subs == 0 then
            mp.osd_message("External subtitles not found")
            return
        end

        result_list.list = {
            {
                sub = nil,
                time = mp.get_property_native("time-pos"),
                ass = "Original position"
            }
        }
        result_list.selected = 1
        result_list.live = live

        local closest_lower_index = 1
        local closest_lower_time = nil
        local cur_time = mp.get_property_native("time-pos")

        local pat = "(" .. make_nocase_pattern(query) .. ")"
        for _, sub in ipairs(subs) do
            for _, sub_line in ipairs(sub.lines) do
                if query == "*" or utf8.match(sub_line.text, pat) then
                    local sub_time = adjust_sub_time(sub_line.time)

                    table.insert(result_list.list, {
                        sub = sub,
                        original_time = sub_line.time,
                        time = sub_time + 0.01, -- to ensure that the subtitle is visible
                        formatter = function(style_reset)
                            local sub_text = result_list.ass_escape(format_time(sub_time) .. ": ") ..
                                    highlight_match(sub_line.text, query, style_reset)

                            if #subs > 1 then
                                sub_text = "[" .. sub.prefix .. "] " .. sub_text
                            end

                            return sub_text
                        end
                    })

                    if sub_time <= cur_time and (closest_lower_time == nil or closest_lower_time < sub_time) then
                        closest_lower_time = sub_time
                        closest_lower_index = #result_list.list
                    end
                end
            end
        end

        result_list.selected = closest_lower_index
        result_list.header = "Search results for \"" .. query .. "\"\\N ------------------------------------"
        result_list.header = result_list.header .. "\\NENTER to jump to subtitle, Ctrl+Shift+Enter to adjust subtitle timing to selected line"

        result_list:update()
        result_list:open()
    end)
end

mp.register_script_message('start-search', function()
    if input_console.is_repl_active() then
        input_console.set_active(false)
    else
        input_console.set_enter_handler(function(query)
            update_search_results_async(query, false)
        end)
        input_console.set_active(true)
    end
end)

mp.register_script_message('show-all-lines', function()
    update_search_results_async("*", true)
end)

local function get_current_subtitle_index(list, pos)
    local closest_lower_index = 1
    local closest_lower_time = nil
    for i, item in ipairs(list) do
        if item.time <= pos and (closest_lower_time == nil or closest_lower_time < item.time) then
            closest_lower_time = item.time
            closest_lower_index = i
        end
    end
    return closest_lower_index
end

mp.observe_property("time-pos", "native", function(_, pos)
    if not result_list.hidden and result_list.live and pos ~= nil then
        local index = get_current_subtitle_index(result_list.list, pos)
        if index > 1 then
            result_list.selected = index
            result_list:update()
        end
    end
end)
