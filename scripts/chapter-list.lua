--[[
    This script implements an interractive chapter list

    This script was written as an example for the mpv-scroll-list api
    https://github.com/CogentRedTester/mpv-scroll-list
]]

local mp = require 'mp'

--adding the source directory to the package path and loading the module
local list = dofile(mp.command_native({"expand-path", "~~/script-modules/scroll-list.lua"}))

--modifying the list settings
list.header = "Chapter List \\N ------------------------------------"

--jump to the selected chapter
local function open_chapter()
    if list.list[list.selected] then
        mp.set_property_number('chapter', list.selected - 1)
    end
end

table.insert(list.keybinds, {'ENTER', 'open_chapter', open_chapter, {} })

local function reinit_list()
    local cur_chapter = mp.get_property_native('chapter')
    local chapter_list = mp.get_property_native('chapter-list', {})

    list.list = {}
    if cur_chapter ~= nil then
        list.selected = cur_chapter + 1
    end

    for i = 1, #chapter_list do
        local item = {}
        if cur_chapter ~= nil and i == cur_chapter + 1 then
            item.style = [[{\c&H33ff66&}]]
        end

        local time = chapter_list[i].time
        if time < 0 then time = 0
        else time = math.floor(time) end
        item.ass = string.format("[%02d:%02d:%02d]", math.floor(time/60/60), math.floor(time/60)%60, time%60)
        item.ass = item.ass..'\\h\\h\\h'..list.ass_escape(chapter_list[i].title)
        list.list[i] = item
    end

    list:update()
end

--update the list when the current chapter changes
mp.observe_property('chapter', 'number', reinit_list)

mp.add_key_binding("F4", "toggle-chapter-browser", function()
    reinit_list()
    list:toggle()
end)
