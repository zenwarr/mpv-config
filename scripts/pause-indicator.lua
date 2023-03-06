local mp = require "mp"
local options = require "mp.options"

local script_options = {
    position = "top-right",
    size = 26,
    show_hourglass = true
}
options.read_options(script_options)

function get_alignment_spec(align)
    local default_align = 3

    if align == "center" then
        return "\\a" .. (2 + 8)
    end

    local sep_index = string.find(align, "-")
    if sep_index == nil then
        print("Invalid align spec: " .. align)
        return default_align
    end

    local y_align = string.sub(align, 1, sep_index - 1)
    local x_align = string.sub(align, sep_index + 1)

    local value = 0
    if x_align == "left" then
        value = 1
    elseif x_align == "center" then
        value = 2
    elseif x_align == "right" then
        value = 3
    else
        print("Invalid x align spec: " .. align)
        return default_align
    end

    if y_align == "top" then
        value = value + 4
    elseif y_align == "center" then
        value = value + 8
    elseif y_align ~= "bottom" then
        print("Invalid y align spec: " .. align)
        return default_align
    end

    return "\\a" .. value
end

local function get_ass_format_string()
    return "{" .. get_alignment_spec(script_options.position) .. "\\fs" .. script_options.size .. "}"
end

local ov = mp.create_osd_overlay('ass-events')

local function update_status()
    is_waiting = mp.get_property_native("paused-for-cache")
    is_seeking = mp.get_property_native("seeking")
    is_paused = mp.get_property_native("pause")
    status_visible = is_waiting or is_seeking or is_paused

    status = ""
    if script_options.show_hourglass and (is_waiting or is_seeking) then
        status = "⌛"
    end

    if is_paused then
        status = status .. "⏸"
    end

    ov.data = get_ass_format_string() .. status

    mp.add_timeout(0.1, function()
        if status_visible then ov:update()
        else ov:remove() end
    end)
end

mp.observe_property('pause', 'native', update_status)
mp.observe_property('paused-for-cache', 'native', update_status)
mp.observe_property('seeking', 'native', update_status)

update_status()
