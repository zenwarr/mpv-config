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
local subtitle = require("subtitle")

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

function load_subtitles_async(on_done)
    local result = {}

    subtitle.load_primary_sub_async(function(primary_sub)
        if primary_sub then
            table.insert(result, primary_sub)
        end

        subtitle.load_secondary_sub_async(function(secondary_sub)
            if secondary_sub then
                table.insert(result, secondary_sub)
            end

            on_done(result)
        end)
    end)
end

function update_search_results_async(query, live)
    load_subtitles_async(function(subs)
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
