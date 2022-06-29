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
    header = "Track List [%cursor%/%total%]\\N ------------------------------------",
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
local listItems = {}

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
    if list.list[list.selected] then
        local itemData = listItems[list.selected]
        if itemData == nil or itemData.disabled then
            return
        end

        local trackId = itemData.id

        if listDest == "video" then
            mp.set_property_number("vid", trackId)
        elseif listDest == "audio" then
            mp.set_property_number("vid", trackId)
        elseif listDest == "sub" then
            mp.set_property_number("sid", trackId)
        elseif listDest == "sub2" then
            mp.set_property_number("secondary-sid", trackId)
        end
    end
end

local function getVideoTrackTitle(trackId)
    local trackTitle = propNative("track-list/" .. trackId .. "/title")
    local trackCodec = propNative("track-list/" .. trackId .. "/codec"):upper()
    local trackImage = propNative("track-list/" .. trackId .. "/image")
    local trackwh = propNative("track-list/" .. trackId .. "/demux-w") .. "x" .. propNative("track-list/" .. trackId .. "/demux-h")
    local trackFps = string.format("%.3f", propNative("track-list/" .. trackId .. "/demux-fps"))
    local trackDefault = propNative("track-list/" .. trackId .. "/default")
    local trackForced = propNative("track-list/" .. trackId .. "/forced")
    local trackExternal = propNative("track-list/" .. trackId .. "/external")
    local filename = propNative("filename/no-ext")

    if trackTitle then trackTitle = trackTitle:gsub(filename, '') end
    if trackExternal then trackTitle = esc_for_title(trackTitle) end
    if trackCodec:match("MPEG2") then trackCodec = "MPEG2"
    elseif trackCodec:match("DVVIDEO") then trackCodec = "DV"
    end

    if trackTitle and not trackImage then trackTitle = trackTitle .. "[" .. trackCodec .. "]" .. ", " .. trackwh .. ", " .. trackFps .. " FPS"
    elseif trackTitle then trackTitle = trackTitle .. "[" .. trackCodec .. "]" .. ", " .. trackwh
    elseif trackImage then trackTitle = "[" .. trackCodec .. "]" .. ", " .. trackwh
    elseif trackFps then trackTitle = "[" .. trackCodec .. "]" .. ", " .. trackwh .. ", " .. trackFps .. " FPS"
    end

    if trackForced then  trackTitle = trackTitle .. ", " .. "Forced" end
    if trackDefault then  trackTitle = trackTitle .. ", " .. "Default" end
    if trackExternal then  trackTitle = trackTitle .. ", " .. "External" end

    return list.ass_escape(trackTitle)
end

local function getAudioTrackTitle(trackId)
    local trackTitle = propNative("track-list/" .. trackId .. "/title")
    local trackLang = propNative("track-list/" .. trackId .. "/lang")
    local trackCodec = propNative("track-list/" .. trackId .. "/codec"):upper()
    -- local trackBitrate = propNative("track-list/" .. trackId .. "/demux-bitrate") / 1000
    local trackSamplerate = propNative("track-list/" .. trackId .. "/demux-samplerate") / 1000
    local trackChannels = propNative("track-list/" .. trackId .. "/demux-channel-count")
    local trackDefault = propNative("track-list/" .. trackId .. "/default")
    local trackForced = propNative("track-list/" .. trackId .. "/forced")
    local trackExternal = propNative("track-list/" .. trackId .. "/external")
    local filename = propNative("filename/no-ext")

    if trackTitle then trackTitle = trackTitle:gsub(filename, '') end
    if trackExternal then trackTitle = esc_for_title(trackTitle) end
    if trackCodec:match("PCM") then trackCodec = "PCM" end

    if trackTitle and trackLang then trackTitle = trackTitle .. ", " .. trackLang .. "[" .. trackCodec .. "]" .. ", " .. trackChannels .. " ch" .. ", " .. trackSamplerate .. " kHz"
    elseif trackTitle then trackTitle = trackTitle .. "[" .. trackCodec .. "]" .. ", " .. trackChannels .. " ch" .. ", " .. trackSamplerate .. " kHz"
    elseif trackLang then trackTitle = trackLang .. "[" .. trackCodec .. "]" .. ", " .. trackChannels .. " ch" .. ", " .. trackSamplerate .. " kHz"
    elseif trackChannels then trackTitle = "[" .. trackCodec .. "]" .. ", " .. trackChannels .. " ch" .. ", " .. trackSamplerate .. " kHz"
    end

    if trackForced then  trackTitle = trackTitle .. ", " .. "Forced" end
    if trackDefault then  trackTitle = trackTitle .. ", " .. "Default" end
    if trackExternal then  trackTitle = trackTitle .. ", " .. "External" end

    return list.ass_escape(trackTitle)
end

local function getSubTrackTitle(trackId)
    local trackTitle = propNative("track-list/" .. trackId .. "/title")
    local trackLang = propNative("track-list/" .. trackId .. "/lang")
    local trackCodec = propNative("track-list/" .. trackId .. "/codec"):upper()
    local trackDefault = propNative("track-list/" .. trackId .. "/default")
    local trackForced = propNative("track-list/" .. trackId .. "/forced")
    local trackExternal = propNative("track-list/" .. trackId .. "/external")
    local filename = propNative("filename/no-ext")

    if trackTitle then trackTitle = trackTitle:gsub(filename, '') end
    if trackExternal then trackTitle = esc_for_title(trackTitle) end
    if trackCodec:match("PGS") then trackCodec = "PGS"
    elseif trackCodec:match("SUBRIP") then trackCodec = "SRT"
    elseif trackCodec:match("VTT") then trackCodec = "VTT"
    elseif trackCodec:match("DVB_SUB") then trackCodec = "DVB"
    elseif trackCodec:match("DVD_SUB") then trackCodec = "VOB"
    end

    if trackTitle and trackLang then trackTitle = trackTitle .. ", " .. trackLang .. "[" .. trackCodec .. "]"
    elseif trackTitle then trackTitle = trackTitle .. "[" .. trackCodec .. "]"
    elseif trackLang then trackTitle = trackLang .. "[" .. trackCodec .. "]"
    elseif trackCodec then trackTitle = "[" .. trackCodec .. "]"
    end

    if trackForced then  trackTitle = trackTitle .. ", " .. "Forced" end
    if trackDefault then  trackTitle = trackTitle .. ", " .. "Default" end
    if trackExternal then  trackTitle = trackTitle .. ", " .. "External" end

    return list.ass_escape(trackTitle)
end


local function updateTrackList(listTitle, trackDest, formatter)
    list.header = listTitle .. ": " .. o.header
    list.list = {}
    listItems = {}

    local tracks = getTracks(trackDest)
    if #tracks ~= 0 then
        for i = 1, #tracks, 1 do
            local trackIndex = tracks[i]
            local trackId = propNative("track-list/" .. trackIndex .. "/id")
            local title = formatter(trackIndex)
            local isDisabled = isTrackDisabled(trackId, trackDest)

            local listItem = {}
            if isTrackSelected(trackId, trackDest) then
                list.selected = i
                listItem.style = [[{\c&H33ff66&}]]
                listItem.ass = "● " .. title
            elseif isDisabled then
                listItem.style = [[{\c&Hff6666&}]]
                listItem.ass = "○ " .. title
            else
                listItem.ass = "○ " .. title
            end
            list.list[i] = listItem
            listItems[i] = {
                id = trackId,
                index = trackIndex,
                disabled = isDisabled
            }
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