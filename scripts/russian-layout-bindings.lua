--[[
As mpv does not natively support shortcuts independent of the keyboard layout (https://github.com/mpv-player/mpv/issues/351), this script tries to workaround this issue for some limited cases with russian (йцукен) keyboard layout.
Upon startup, it takes currently active bindings from `input-bindings` property and duplicates them for the russian layout.
You can adapt the script for your preferred layout, but it won't (of course) work for layouts sharing unicode characters with the english layout.

Known issues:
- When bindings are defined in `input.conf`, mpv determines by the attached command whether this binding should be repeatable or not.
  But when defining a binding from inside a script, the script should decide whether the binding should be repeatable.
  And mpv does not give any information on whether a binding was detected to be repeatable, so we have no easy way to determine this.
  So this script uses a quick and dirty solution: it just checks if the command has `repeatable` word in it and if it does, it sets the binding to be repeatable.
  And if you define a binding in `input.conf` and you want its translated counterpart to be repeatable too, you should explicitly add `repeatable` prefix to the command (for example: translated shortcut for `. sub-seek 1` is not going to be repeatable while `. repeatable sub-seek 1` is).
]]--

local mp = require("mp")

-- map keys on english-layout keyboard to russian-layout keyboard
local key_mapping = {}
key_mapping["q"] = "й"
key_mapping["w"] = "ц"
key_mapping["e"] = "у"
key_mapping["r"] = "к"
key_mapping["t"] = "е"
key_mapping["y"] = "н"
key_mapping["u"] = "г"
key_mapping["i"] = "ш"
key_mapping["o"] = "щ"
key_mapping["p"] = "з"
key_mapping["a"] = "ф"
key_mapping["s"] = "ы"
key_mapping["d"] = "в"
key_mapping["f"] = "а"
key_mapping["g"] = "п"
key_mapping["h"] = "р"
key_mapping["j"] = "о"
key_mapping["k"] = "л"
key_mapping["l"] = "д"
key_mapping["z"] = "я"
key_mapping["x"] = "ч"
key_mapping["c"] = "с"
key_mapping["v"] = "м"
key_mapping["b"] = "и"
key_mapping["n"] = "т"
key_mapping["m"] = "ь"
key_mapping["Q"] = "Й"
key_mapping["W"] = "Ц"
key_mapping["E"] = "У"
key_mapping["R"] = "К"
key_mapping["T"] = "Е"
key_mapping["Y"] = "Н"
key_mapping["U"] = "Г"
key_mapping["I"] = "Ш"
key_mapping["O"] = "Щ"
key_mapping["P"] = "З"
key_mapping["A"] = "Ф"
key_mapping["S"] = "Ы"
key_mapping["D"] = "В"
key_mapping["F"] = "А"
key_mapping["G"] = "П"
key_mapping["H"] = "Р"
key_mapping["J"] = "О"
key_mapping["K"] = "Л"
key_mapping["L"] = "Д"
key_mapping["Z"] = "Я"
key_mapping["X"] = "Ч"
key_mapping["C"] = "С"
key_mapping["V"] = "М"
key_mapping["B"] = "И"
key_mapping["N"] = "Т"
key_mapping["M"] = "Ь"
key_mapping[","] = "б"
key_mapping["."] = "ю"
key_mapping["`"] = "ё"
key_mapping["["] = "х";
key_mapping["]"] = "ъ";

local function split(inputstr, sep)
    local result = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(result, str)
    end
    return result
end

function guess_repeatable_command(cmd)
    local parts = split(cmd, " ")
    for _, part in ipairs(parts) do
        if part == "repeatable" then
            return true
        end
    end
    return false
end


-- we do not have a way to order plugin loading, so we have to wait until mpv loads other plugins and then do our job
mp.add_timeout(0.5, function()
    local bindings = mp.get_property_native("input-bindings")

    for _, binding in ipairs(bindings) do
        parts = split(binding.key, "+")
        translated = {}
        needs_translate = false

        for _, binding_part in ipairs(parts) do
            if key_mapping[binding_part] ~= nil then
                table.insert(parts, key_mapping[binding_part])
                needs_translate = true
            else
                table.insert(translated, binding_part)
            end
        end

        if needs_translate then
            translated_key = table.concat(translated, "+")
            mp.add_key_binding(translated_key, function()
                mp.command(binding.cmd)
            end, {
                repeatable = guess_repeatable_command(binding.cmd)
            })
        end
    end
end)
