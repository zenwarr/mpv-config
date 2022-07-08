local mp = require("mp")

local osc_visible = false

mp.register_script_message("toggle", function()
    if not osc_visible then
        mp.commandv("script-message", "osc-visibility", "always", "no-osd")
        osc_visible = true
    else
        mp.commandv("script-message", "osc-visibility", "never", "no-osd")
        osc_visible = false
    end
end)
