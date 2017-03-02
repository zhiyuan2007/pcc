cjson = require 'cjson.safe'
redis = require 'redis'
common = require 'common'

local function read_user_friendship_from_file(filename)
    local fp = io.open(filename, "r")
    if not fp then
        ngx.log(ngx.ERR, "open file failed")
        return
    end
    while 1 do
        local line = fp:read("*l") 
        if not line then
           ngx.log(ngx.WARN, "end of file")
           break
        end
        if string.sub(line, 1,1 ) == '#' then
            goto goon
        end
        linedata = common.lua_split(line, ",") 
        if #linedata == 2 then
           uid = linedata[1] 
           fid = linedata[2]
           common.add_friend_handler(uid,fid)
        end
        ::goon::
    end
    fp:close()
end

local function read_object_likeship_from_file(filename)
    local fp = io.open(filename, "r")
    if not fp then
        ngx.log(ngx.ERR, "open file failed")
        return
    end
    while 1 do
        local line = fp:read("*l") 
        if not line then
           ngx.log(ngx.WARN, "end of file")
           break
        end
        if string.sub(line, 1,1 ) == '#' then
            goto goon
        end
        linedata = common.lua_split(line, ":") 
        if #linedata == 2 then
           oid = linedata[1] 
           if string.sub(linedata[2], 1, 1) == '[' and string.sub(linedata[2], -1, -1) == ']' then
              uid_str = string.sub(linedata[2], 2, -2)
              uid_list = common.lua_split(uid_str, ",")
              for uid in ipairs(uid_list) do
                  --ngx.log(ngx.WARN, "oid ", oid, " uid " , uid)
                  common.like_handler(oid, uid, nil,nil)
              end
           end
            
        end
        ::goon::
    end
    fp:close()
end

read_user_friendship_from_file("/home/liuguirong/nginx/conf/data/friends.txt")
read_object_likeship_from_file("/home/liuguirong/nginx/conf/data/likes.txt")


