--[[
    This script implements an interractive chapter list

    This script was written as an example for the mpv-scroll-list api
    https://github.com/CogentRedTester/mpv-scroll-list
]]

local mp = require 'mp'

--adding the source directory to the package path and loading the module
local list = dofile(mp.command_native({"expand-path", "~~/script-modules/scroll-list.lua"}))

--modifying the list settings
list.header = "Playlist \\N ------------------------------------"

--jump to the selected chapter
local function open_item()
    if list.list[list.selected] then
        mp.commandv("playlist-play-index", list.selected - 1)
    end
end

table.insert(list.keybinds, { 'ENTER', 'open_item', open_item, {} })

local function reinit_list()
    local cur_item = mp.get_property_native('playlist-pos')
    local playlist = mp.get_property_native('playlist', {})

    list.list = {}
    if cur_item ~= nil then
        list.selected = cur_item + 1
    end

    for i = 1, #playlist do
        local item = {}
        if cur_item ~= nil and i == cur_item + 1 then
            item.style = [[{\c&H33ff66&}]]
        end

        item.ass = '\\h\\h\\h'..list.ass_escape(playlist[i].title or playlist[i].filename)
        list.list[i] = item
    end

    list:update()
end

mp.observe_property('playlist', 'native', reinit_list)

mp.register_script_message("toggle", function()
    reinit_list()
    list:toggle()
end)
