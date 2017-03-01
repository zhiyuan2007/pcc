local _M = {}

function new_redis()

    local red = redis:new()

    red:set_timeout(3000)

    local ok, err = red:connect("unix:/var/lib/redis/redis.sock")
    if not ok then
        ngx.log(ngx.CRIT, err)
        return nil
    end
    local ok, err = red:select(1)
    if not ok then
        ngx.log(ngx.CRIT, err)
        return nil
    end
    return red
end
local function list_to_table(list)

    local res = {}

    for i = 1, #(list), 2 do
        res[list[i]] = list[i + 1]
    end

    return res
end

local function response_like(oid, uid)
    local res =  {}
    res["oid"] = oid
    res["uid"] = uid
    res["like_list"] = {uid}
    return cjson.encode(res)
end

local function response_islike(oid, uid, islike)
    local res =  {}
    res["oid"] = oid
    res["uid"] = uid
    res["islike"] = islike or 0
    return cjson.encode(res)
end

local function response_count(oid, count)
    local res =  {}
    res["oid"] = oid
    res["count"] = count 
    return cjson.encode(res)
end

local function response_page_size(oid, like_list)
    local res = {}
    res["oid"] = oid
    res["like_list"] = like_list 
    return cjson.encode(res)
end

local function response_err_msg(oid, uid, error_code, error_msg)
    local res = {}
    res["oid"] = oid
    res["uid"] = uid
    res["error_code"] = error_code 
    res["error_msg"] =  error_msg
    return cjson.encode(res)
end

local function is_like(shm, oid, uid) 
   return shm:get( "like:" .. oid .. "," .. uid)
end

local function check_validity(action, oid, uid) 
    if not action then
        return 502, "no action"
    end
    if not oid then
        return 503, "no oid"
    end
    
    if action == "like" or action == "islike" then
       if not uid then
          return 504, "no uid" 
       end
    end
    return 200, "ok"
end

_M = {
    new_redis                = new_redis,
    lua_split                = lua_split,
    response_islike          = response_islike,
    response_count           = response_count,
    response_page_size       = response_page_size,
    response_err_msg         = response_err_msg,
    response_like            = response_like,
    check_validity           = check_validity,
    is_like                  = is_like
}
return _M

