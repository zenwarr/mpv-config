--[[
Based on sub-search script by kelciour (https://github.com/kelciour/mpv-scripts/blob/master/sub-search.lua)

Differences from the original script:

- Searches in a subtitle file active as a primary subtitle instead of attempting to find subtitle files matching video name
- Outputs all search results in OSD list instead of jumping between them with a hotkey (the closest subtitle is selected by default)
- Supports searching unicode text (subtitles should be encoded as utf8, please re-encode your subtitles if you get no results searching for unicode text)
- Embedded console replaced with more recent variant from mpv sources (to support unicode input)
- Takes into account current `sub-delay` value
- Can use special phrase "*" to show all subtitles

Requires `script-modules/utf8` repository, `script-modules/scroll-list.lua` and `script-modules/input-console.lua` to work.

You can clone `script-modules/utf8` repository with the following command (assuming you are in mpv config directory): `git clone git@github.com:Stepets/utf8.lua.git script-modules/utf8`

Usage:
    Press Ctrl + F, print something and press Enter.
Example:
    'You are playing Empire Strikes Back and press Ctrl+F, type "I am you father" + Enter
    and voilá, the scene pops up.'
Additional Keybidings:
    Ctrl+F - open or close search console
More Information:
    The search is case insensitive and depends on the external .srt subtitles.
Console Settings:
    Update repl.lua default options below to increase the default font size.
    For example, scale or font-size.
--]]

package.path = package.path .. ";" .. mp.command_native({"expand-path", "~~/script-modules/?.lua"})

local input_console = require("input-console")
local result_list = require("scroll-list")
local utf8 = require("utf8/init"):init()

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

function srt_time_to_seconds(time)
    local major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    local hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

function open_subtitles_file()
    local active_track = mp.get_property_native("current-tracks/sub")
    if active_track == nil then
        return nil
    end

    local is_external = active_track.external
    local external_filename = active_track["external-filename"]

    if is_external and external_filename then
        local f, err = io.open(external_filename, "r")
        if f and err == nil then
            return f
        end
    end

    return nil
end

function get_lines(inputstr)
    local lines = {}

    local tail = 1
    for head = 1, #inputstr do
        local ch = inputstr:sub(head, head)
        if ch == "\n" then
            table.insert(lines, inputstr:sub(tail, head - 1))
            tail = head + 1
        elseif head == #inputstr then
            table.insert(lines, inputstr:sub(tail, head))
        end
    end

    return lines
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function load_subtitles_file()
    local f = open_subtitles_file()

    if not f then
        return false
    end

    local data = f:read("*all")
    f:close()

    data = string.gsub(data, "\r\n", "\n")
    data = string.gsub(data, "<b>", "")
    data = string.gsub(data, "</b>", "")
    data = string.gsub(data, "<i>", "")
    data = string.gsub(data, "</i>", "")
    data = string.gsub(data, "<u>", "")
    data = string.gsub(data, "</u>", "")

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
                cur_line.time = srt_time_to_seconds(time_text)
                state = "waiting_text"
            else
                state = "waiting_index"
            end
        elseif state == "waiting_text" then
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

function make_nocase_pattern(s)
    local result = ""
    for _, code in utf8.codes(s) do
        local c = utf8.char(code)
        result = result .. string.format("[%s%s]", utf8.lower(c), utf8.upper(c))
    end
    return result
end

-- highlight found text with colored text in ass syntax
-- todo: it breaks current item highlighting right now
function highlight_match(text, match_text)
    local match_start, match_end = utf8.find(utf8.lower(text), utf8.lower(match_text))
    if match_start == nil then
        return text
    end

    local before = result_list.ass_escape(utf8.sub(text, 1, match_start - 1))
    local match = result_list.ass_escape(utf8.sub(text, match_start, match_end))
    local after = result_list.ass_escape(utf8.sub(text, match_end + 1))

    return before .. "{\\c&HFF00&}" .. match .. "{\\c&HFFFFFF&}" .. after
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
    local h, s = divmod(s, 60*60)
    local m, s = divmod(s, 60)

    local second_format = string.format("%%0%d.%df", 2+(decimals > 0 and decimals+1 or 0), decimals)

    return string.format("%02d"..sep.."%02d"..sep..second_format, h, m, s)
end

sub_lines = nil

function update_search_results(phrase)
    if sub_lines == nil then
        sub_lines = load_subtitles_file()
        if sub_lines == false then
            mp.osd_message("Can't find external subtitles")
            return
        end
    end

    result_list.list = {
        {
            time = mp.get_property_native("time-pos"),
            ass = "Original position"
        }
    }
    result_list.selected = 1

    local closest_lower_index = 1
    local closest_lower_time = nil
    local cur_time = mp.get_property_native("time-pos")

    local pat = "(" .. make_nocase_pattern(phrase) .. ")"
    for _, sub_line in ipairs(sub_lines) do
        if phrase == "*" or utf8.match(sub_line.text, pat) then
            local sub_time = adjust_sub_time(sub_line.time)
            table.insert(result_list.list, {
                time = sub_time + 0.01, -- to ensure that the subtitle is visible
                ass = result_list.ass_escape(format_time(sub_time) .. ": ") .. highlight_match(sub_line.text, phrase),
            })

            if sub_line.time <= cur_time and (closest_lower_time == nil or closest_lower_time < sub_time) then
                closest_lower_time = sub_time
                closest_lower_index = #result_list.list
            end
        end
    end

    result_list.selected = closest_lower_index
    result_list.header = "Search results for \"" .. phrase .. "\"\\N ------------------------------------"

    result_list:update()
    result_list:open()
end

mp.add_key_binding('ctrl+f', 'search-toggle', function()
    if input_console.is_repl_active() then
        input_console.set_active(false)
    else
        input_console.set_active(true)
    end
end)
