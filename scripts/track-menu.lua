--[[
    * track-menu.lua v.2022-06-26
    *
    * AUTHORS: dyphire
    * License: MIT
    * link: https://github.com/dyphire/mpv-scripts

    This script implements an interractive track list, usage:
    -- add bindings to input.conf:
    -- key script-message-to track_menu toggle-vidtrack-browser
    -- key script-message-to track_menu toggle-audtrack-browser
    -- key script-message-to track_menu toggle-subtrack-browser

    This script needs to be used with scroll-list.lua
    https://github.com/dyphire/mpv-scroll-list
]]

local mp = require 'mp'
local opts = require("mp.options")
local propNative = mp.get_property_native

local o = {
    header = "Track List\\N ------------------------------------",
    wrap = true,
    key_scroll_down = "DOWN WHEEL_DOWN",
    key_scroll_up = "UP WHEEL_UP",
    key_select_track = "ENTER MBTN_LEFT",
    key_close_browser = "ESC MBTN_RIGHT",
}

opts.read_options(o)

--adding the source directory to the package path and loading the module
local list = dofile(mp.command_native({"expand-path", "~~/script-modules/scroll-list.lua"}))
local listDest = nil

--modifying the list settings
list.header = o.header
list.wrap = o.wrap

local function esc_for_title(string)
    string = string:gsub('^%-', '')
    :gsub('^%_', '')
    :gsub('^%.', '')
    :gsub('^.*%].', '')
    :gsub('^.*%).', '')
    :gsub('%.%w+$', '')
    :gsub('^.*%s', '')
    :gsub('^.*%.', '')
    return string
end

local function getTracks(dest)
    local tracksCount = propNative("track-list/count")
    local trackCountVal = {}

    if not (tracksCount < 1) then
        for i = 0, (tracksCount - 1), 1 do
            local trackType = propNative("track-list/" .. i .. "/type")
            if trackType == dest or (trackType == "sub" and dest == "sub2") then
                table.insert(trackCountVal, i)
            end
        end
    end

    return trackCountVal
end

local function isTrackSelected(trackId, dest)
    local selectedId = propNative("current-tracks/" .. dest .. "/id")
    return selectedId == trackId
end

local function isTrackDisabled(trackId, dest)
    return (dest == "sub2" and isTrackSelected(trackId, "sub")) or (dest == "sub" and isTrackSelected(trackId, "sub2"))
end

local function selectTrack()
    local selected = list.list[list.selected]
    if selected then
        if selected.disabled then
            return
        end

        local trackId = selected.id
        if trackId == nil then
            trackId = "no"
        end

        if listDest == "video" then
            mp.set_property_native("vid", trackId)
        elseif listDest == "audio" then
            mp.set_property_native("aid", trackId)
        elseif listDest == "sub" then
            mp.set_property_native("sid", trackId)
        elseif listDest == "sub2" then
            mp.set_property_native("secondary-sid", trackId)
        end
    end
end

local function get_external_or_embed_string(track)
    if track.external then
        return "external"
    else
        local index = track["ff-index"]
        if index then
            return string.format("embedded #%d", index)
        else
            return "embedded"
        end
    end
end

local function getVideoTrackTitle(trackId)
    local track = mp.get_property_native("track-list/" .. trackId)

    local title = track.title
    if title then
        title = title:gsub(mp.get_property_native("filename/no-ext"), '')
    end

    local codec = track.codec
    if codec then
        codec = codec:lower()
    end

    local width = track["demux-w"]
    local height = track["demux-h"]

    local dims
    if width and height then
        dims = string.format("%sx%s", tostring(width), tostring(height))
    end

    local fps = track["demux-fps"]
    if fps then
        fps = string.format("%dfps", fps)
    end

    local is_external = track.external
    if is_external and not title and track.external_filename then
        title = track.external_filename
    end

    local main_title = title or dims or string.format("#%d", track["ff-index"] or trackId)

    local dim_elem = nil
    if main_title ~= dims then
        dim_elem = dims
    end
    local sub_title = join({ dim_elem, fps, codec, get_external_or_embed_string(track) })

    return list.ass_escape(main_title, 20) .. " {\\c&H999999&\\fs20}" .. list.ass_escape(sub_title) .. "{}"
end

local function getAudioTrackTitle(trackId)
    local track = mp.get_property_native("track-list/" .. trackId)

    local title = track.title
    if title then
        title = title:gsub(mp.get_property_native("filename/no-ext"), '')
    end

    local lang = track.lang
    if lang then
        lang = lang:upper()
    end

    local codec = track.codec
    if codec then
        codec = codec:lower()
    end

    local bitrate = track["demux-samplerate"]
    if bitrate then
        bitrate = bitrate / 1000
        bitrate = string.format("%.0fKHz", bitrate)
    end

    local channels = track["audio-channels"]
    if channels then
        channels = string.format("%d channels", channels)
    end

    local main_title = title or lang or string.format("#%d", track["ff-index"] or trackId)
    local sub_title = join({ lang, codec, channels, bitrate, get_external_or_embed_string(track) })

    return list.ass_escape(main_title, 20) .. " {\\c&H999999&\\fs20}" .. list.ass_escape(sub_title) .. "{}"
end

local function getSubTrackTitle(trackId)
    local track = mp.get_property_native("track-list/" .. trackId)

    local title = track.title
    if title then
        title = title:gsub(mp.get_property_native("filename/no-ext"), '')
    end

    local lang = track.lang
    if lang then
        lang = lang:upper()
    end

    local codec = track.codec
    if codec then
        codec = codec:lower()
    end

    local main_title = title or lang or string.format("#%d", track["ff-index"] or trackId)
    local sub_title = join({ lang, codec, get_external_or_embed_string(track) })

    return list.ass_escape(main_title, 20) .. " {\\c&H999999&\\fs20}" .. list.ass_escape(sub_title) .. "{}"
end

function join(strings, delimiter)
    delimiter = delimiter or ", "
    local result = ""

    for i, str in pairs(strings) do
        if str then
            result = result .. str

            if i < #strings then
                result = result .. delimiter
            end
        end
    end

    return result
end

function padString(str, length)
    if #str < length then
        return str .. string.rep(" ", length - #str)
    else
        return str
    end
end

function printTable(obj, indent)
    indent = indent or 2
    local indentStr = string.rep(" ", indent)

    if type(obj) == "table" then
        for k, v in pairs(obj) do
            io.write(indentStr, k, " = ")
            if type(v) == "table" then
                io.write("{\n")
                printTable(v, indent + 2)
                io.write(indentStr, "}\n")
            else
                io.write(tostring(v), "\n")
            end
        end
    else
        io.write(tostring(obj), "\n")
    end
end


local function updateTrackList(listTitle, trackDest, formatter)
    list.header = listTitle .. ": " .. o.header
    list.list = {
        {
            id = nil,
            index = nil,
            disabled = false,
            ass = "○ None"
        }
    }

    if isTrackSelected(nil, trackDest) then
        list.selected = 1
        list[1].ass = "● None"
        list[1].style = [[{\c&H33ff66&}]]
    end

    local tracks = getTracks(trackDest)
    if #tracks ~= 0 then
        for i = 1, #tracks, 1 do
            local trackIndex = tracks[i]
            local trackId = propNative("track-list/" .. trackIndex .. "/id")
            local title = formatter(trackIndex)
            local isDisabled = isTrackDisabled(trackId, trackDest)

            local listItem = {
                id = trackId,
                index = trackIndex,
                disabled = isDisabled
            }
            if isTrackSelected(trackId, trackDest) then
                list.selected = i + 1
                listItem.style = [[{\c&H33ff66&}]]
                listItem.ass = "● " .. title
            elseif isDisabled then
                listItem.style = [[{\c&Hff6666&}]]
                listItem.ass = "○ " .. title
            else
                listItem.ass = "○ " .. title
            end
            table.insert(list.list, listItem)
        end
    end

    list:update()
end

local function updateVideoTrackList()
    updateTrackList("Video", "video", getVideoTrackTitle)
end

local function updateAudioTrackList()
    updateTrackList("Audio", "audio", getAudioTrackTitle)
end

local function updateSubTrackList()
    updateTrackList("Subtitle", "sub", getSubTrackTitle)
end

-- Secondary subtitle track-list menu
local function updateSecondarySubTrackList()
    updateTrackList("Secondary Subtitle", "sub2", getSubTrackTitle)
end

--dynamic keybinds to bind when the list is open
list.keybinds = {}

local function add_keys(keys, name, fn, flags)
    local i = 1
    for key in keys:gmatch("%S+") do
      table.insert(list.keybinds, {key, name..i, fn, flags})
      i = i + 1
    end
end

add_keys(o.key_scroll_down, 'scroll_down', function() list:scroll_down() end, {repeatable = true})
add_keys(o.key_scroll_up, 'scroll_up', function() list:scroll_up() end, {repeatable = true})
add_keys(o.key_select_track, 'select_track', selectTrack, {})
add_keys(o.key_close_browser, 'close_browser', function() list:close() end, {})

local function setTrackChangeHandler(property, func)
    mp.unobserve_property(updateVideoTrackList)
    mp.unobserve_property(updateAudioTrackList)
    mp.unobserve_property(updateSubTrackList)
    mp.unobserve_property(updateSecondarySubTrackList)
    if func ~= nil then
        mp.observe_property("track-list/count", "number", func)
        mp.observe_property(property, "string", func)
    end
end

local function toggleListDelayed(dest)
    listDest = dest
    mp.add_timeout(0.1, function()
        list:toggle()
    end)
end

local function openVideoTrackList()
    list:close()
    setTrackChangeHandler("vid", updateVideoTrackList)
    toggleListDelayed("video")
end

local function openAudioTrackList()
    list:close()
    setTrackChangeHandler("aid", updateAudioTrackList)
    toggleListDelayed("audio")
end

local function openSubTrackList()
    list:close()
    setTrackChangeHandler("sid", updateSubTrackList)
    toggleListDelayed("sub")
end

local function openSecondarySubTrackList()
    list:close()
    setTrackChangeHandler("secondary-sid", updateSecondarySubTrackList)
    toggleListDelayed("sub2")
end

mp.register_script_message("toggle-vidtrack-browser", openVideoTrackList)
mp.register_script_message("toggle-audtrack-browser", openAudioTrackList)
mp.register_script_message("toggle-subtrack-browser", openSubTrackList)
mp.register_script_message("toggle-secondary-subtrack-browser", openSecondarySubTrackList)

mp.register_event("end-file", function()
    setTrackChangeHandler(nil, nil)
end)
