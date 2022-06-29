local mp = require "mp"

local function start_blackout()
	mp.set_property("pause", "yes")
	mp.set_property("window-minimized", "yes")
end

mp.register_script_message("start", start_blackout)
