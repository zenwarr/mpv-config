--[[
As mpv does not natively support shortcuts independent of the keyboard layout (https://github.com/mpv-player/mpv/issues/351), this script tries to workaround this issue for some limited cases with russian (йцукен) keyboard layout.
Upon startup, it takes currently active bindings from `input-bindings` property and duplicates them for russian layout.
You can adapt the script for your preferred layout, but it won't (of course) work for layouts sharing unicode characters with english layout.
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

local bindings = mp.get_property_native("input-bindings")

local function split(inputstr, sep)
    local result = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(result, str)
    end
    return result
end

-- iterate over all bindings and add translated bindings
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
        end)
    end
end
