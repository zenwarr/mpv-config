local mp = require 'mp'
local options = require "mp.options"
local msg = require "mp.msg"

local function split(inputstr, sep)
  local result = {}

  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(result, str)
  end

  return result
end


local opts = {
  profiles = ""
}
options.read_options(opts, "load-profiles")

for _, profile in pairs(split(opts.profiles, ",")) do
  msg.log("info", "applying profile " .. profile)
  mp.commandv("apply-profile", profile)
end
