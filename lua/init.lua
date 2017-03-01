cjson = require 'cjson.safe'
redis = require 'redis'
luabit = require 'bit'
common = require 'common'
ffi = require("ffi")
ffi_new = ffi.new


-- Init random seed --
math.randomseed(os.time())
