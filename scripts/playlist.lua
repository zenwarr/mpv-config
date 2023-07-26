--[[
    This script implements an interractive chapter list

    This script was written as an example for the mpv-scroll-list api
    https://github.com/CogentRedTester/mpv-scroll-list
]]

package.path = package.path .. ";" .. mp.command_native({ "expand-path", "~~/script-modules/?.lua" })

local mp = require 'mp'
local utils = require 'mp.utils'
local list = require 'scroll-list'

--modifying the list settings
list.header = "Playlist \\N ------------------------------------"

--jump to the selected chapter
local function open_item()
    if list.list[list.selected] then
        mp.commandv("playlist-play-index", list.selected - 1)
    end
end

table.insert(list.keybinds, { 'ENTER', 'open_item', open_item, {} })

local function get_trimmed_array(arr, end_index)
    local new_arr = {}
    for i = 1, end_index do
        new_arr[i] = arr[i]
    end
    return new_arr
end

local function split(inputstr, sep)
    local result = {}

    for str in inputstr:gmatch("([^" .. sep .. "]+)") do
        table.insert(result, str)
    end

    return result
end

local function min(a, b)
    if a < b then
        return a
    else
        return b
    end
end

local function get_dir(path)
    local prefix, _ = utils.split_path(path)
    return prefix
end

local function get_common_prefix_len(items)
    if #items == 0 then
        return 0
    end
    
    local prefix = get_dir(items[1])

    for i = 1, #items[1] do
        local cur_item = items[i]
        if cur_item == nil then
            break
        end

        cur_item = get_dir(cur_item)

        local prev_sep_index = -1
        for ch_idx = 1, min(#prefix, #cur_item) do
            if prefix:sub(ch_idx, ch_idx) ~= cur_item:sub(ch_idx, ch_idx) then
                prefix = prefix:sub(1, prev_sep_index + 1)
                break
            elseif prefix:sub(ch_idx, ch_idx) == '/' then
                prev_sep_index = ch_idx
            end
        end
    end

    return #prefix
end

local function reinit_list()
    local cur_item = mp.get_property_native('playlist-pos')
    local playlist = mp.get_property_native('playlist', {})

    list.list = {}
    if cur_item ~= nil then
        list.selected = cur_item + 1
    end

    local titles = {}
    for i = 1, #playlist do
        titles[i] = playlist[i].title or playlist[i].filename
    end

    local common_prefix_len = get_common_prefix_len(titles)

    for i = 1, #playlist do
        local item = {}
        if cur_item ~= nil and i == cur_item + 1 then
            item.style = [[{\c&H33ff66&}]]
        end

        local item_text = titles[i]:sub(common_prefix_len)
        item.ass = '\\h\\h\\h'..list.ass_escape(item_text)
        list.list[i] = item
    end

    list:update()
end

mp.observe_property('playlist', 'native', reinit_list)

mp.register_script_message("toggle", function()
    reinit_list()
    list:toggle()
end)
