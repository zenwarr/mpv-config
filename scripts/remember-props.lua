local mp = require("mp")
local options = require("mp.options")
local utils = require("mp.utils")


local data_file_path = (os.getenv('APPDATA') or os.getenv('HOME') .. '/.config') ..'/mpv/saved-props.json'


local function split(inputstr, sep)
    local result = {}

    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(result, str)
    end

    return result
end


local script_options = {
    props = ""
}
options.read_options(script_options, "remember-props")
script_options.props = split(script_options.props, ",")


local function read_data_file()
    local json_file = io.open(data_file_path, 'a+')
    local result = utils.parse_json(json_file:read("*all"))
    if result == nil then
        result = {}
    end
    json_file:close()

    return result
end


local saved_data = read_data_file()


local function save_data_file()
    local file = io.open(data_file_path, 'w+')
    if file == nil then
        return
    end

    local content, ret = utils.format_json(saved_data)
    if ret ~= error and content ~= nil then
        file:write(content)
    end

    file:close()
end


local function init()
    for _, prop_name in ipairs(script_options.props) do
        local saved_value = saved_data[prop_name]
        if saved_value ~= nil then
            mp.set_property_native(prop_name, saved_value)
        end

        mp.observe_property(prop_name, "native", function(_, prop_value)
            saved_data[prop_name] = mp.get_property_native(prop_name)
            save_data_file()
        end)
    end
end


init()
