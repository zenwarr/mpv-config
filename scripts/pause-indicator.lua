local mp = require "mp"

local ov = mp.create_osd_overlay('ass-events')

ov.data = "{\\a7\\fs26}⏸"

mp.observe_property('pause', 'bool', function(_, paused)
    mp.add_timeout(0.1, function()
        if paused then ov:update()
        else ov:remove() end
    end)
end)
