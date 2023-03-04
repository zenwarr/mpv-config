local mp = require "mp"
local options = require "mp.options"

local script_options = {
    position = "bottom-right",
    size = 13,
    time_format = "%H:%M", -- details: https://www.lua.org/pil/22.1.html,
    show_end = true,
    end_prefix = "ends at ",
    enabled_by_default = true
}
options.read_options(script_options)

local clock_overlay = mp.create_osd_overlay('ass-events')
local overlay_visible = script_options.enabled_by_default
local update_timer = nil

function get_alignment_spec(align)
    local default_align = 3

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

function get_clock()
    local clock = os.date(script_options.time_format)
    if not script_options.show_end then
        return clock
    end

    local dt = os.date("*t")
    local rem = mp.get_property_native("playtime-remaining")
    if rem == nil then
        return clock
    end

    dt.sec = dt.sec + rem
    local formatted_end = " [" .. script_options.end_prefix .. os.date(script_options.time_format, os.time(dt)) .. "]"

    return clock .. formatted_end
end

function update_clock()
    if not overlay_visible then
        return
    end

    local ass_format_string = "{" .. get_alignment_spec(script_options.position) .. "\\fs" .. script_options.size .. "}"
    clock_overlay.data = ass_format_string .. get_clock()
    clock_overlay:update()
end

function activate_timer()
    if not overlay_visible then
        return
    end

    if update_timer ~= nil then
        update_timer:resume()
    else
        update_timer = mp.add_periodic_timer(0.5, function()
            update_clock()
        end)
    end
end

function deactivate_timer()
    if update_timer ~= nil then
        update_timer:kill()
    end
end

mp.register_script_message("toggle", function()
    if overlay_visible then
        deactivate_timer()
        clock_overlay:remove()
        overlay_visible = false
    else
        overlay_visible = true
        update_clock()
        activate_timer()
    end
end)

update_clock()
activate_timer()
