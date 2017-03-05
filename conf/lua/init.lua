cjson = require 'cjson.safe'
redis = require 'redis'
common = require 'common'
mysql = require "resty.mysql"

lock = require "lock"
insert_lock = lock:new("insert_lock")

local LINE_COUNT = 100
PORT = 3306
DATABASE = "pcc"
USER = "pcc"
PASSWORD = "pcc"

IS_TTL = 10
COUNT_TTL = 5
LIST_TTL = 10
OBJ_LIST_TTL = 10
FRIEND_TTL = 30

SERVER = {"192.168.0.3", "192.168.0.4", "192.168.0.5"}

action_handler_obj = {
     ["like"] = common.like_handler,
     ["batch_like"] = common.batch_like_handler,
     ["is_like"] = common.islike_handler,
     ["count"] = common.count_handler,
}
