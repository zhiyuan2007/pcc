cjson = require 'cjson.safe'
redis = require 'redis'
luabit = require 'bit'
common = require 'common'

-- Init random seed --
math.randomseed(os.time())
