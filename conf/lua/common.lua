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

local function is_like(shm, oid, uid) 
   return shm:get( "like:" .. oid .. "," .. uid)
end


_M = {
    new_redis                = new_redis,
    lua_split                = lua_split,
    response_islike          = response_islike,
    response_count           = response_count,
    response_page_size       = response_page_size,
    is_like                  = is_like,
    response_like            = response_like
}
return _M

