local mp = require "mp"

local ov = mp.create_osd_overlay('ass-events')

ov.data = "{\\a7\\fs26}"

local function update_status()
    is_waiting = mp.get_property_native("paused-for-cache")
    is_seeking = mp.get_property_native("seeking")
    is_paused = mp.get_property_native("pause")
    status_visible = is_waiting or is_seeking or is_paused

    status = ""
    if is_waiting or is_seeking then
        status = "⌛"
    end

    if is_paused then
        status = status .. "⏸"
    end

    ov.data = "{\\a7\\fs26}" .. status

    mp.add_timeout(0.1, function()
        if status_visible then ov:update()
        else ov:remove() end
    end)
end

mp.observe_property('pause', 'native', update_status)
mp.observe_property('paused-for-cache', 'native', update_status)
mp.observe_property('seeking', 'native', update_status)
