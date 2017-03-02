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

local function response_like(oid, uid, like_list)
    local res = {
                 oid = tonumber(oid),
                 uid = tonumber(uid),
                 like_list = like_list
                }
    return cjson.encode(res)
end

local function response_islike(oid, uid, islike)
    local res =  {}
    res["oid"] = tonumber(oid)
    res["uid"] = tonumber(uid)
    res["islike"] = islike
    return cjson.encode(res)
end

local function response_count(oid, count)
    local res =  {}
    res["oid"] = tonumber(oid)
    res["count"] = count 
    return cjson.encode(res)
end

local function response_page_size(oid, like_list)
    local res = {}
    res["oid"] = tonumber(oid)
    res["like_list"] = like_list 
    return cjson.encode(res)
end

local function response_err_msg(oid, uid, error_code, error_msg)
    local res = {}
    res["oid"] = tonumber(oid)
    res["uid"] = tonumber(uid)
    res["error_code"] = error_code 
    res["error_msg"] =  error_msg
    return cjson.encode(res)
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

local function table_keys( t )
    local keys = {}
    for k, _ in pairs( t ) do
        if string.sub(k, 1, 1) ~= '_'  then
           keys[#keys + 1] = k
        end
    end
    return keys
end

local function table_keys_first_n(t, n)
    local keys = {}
    for k, _ in pairs( t ) do
        if string.sub(k, 1, 1) ~= '_'  then
           keys[#keys + 1] = tonumber(k)
           if (#keys >= n) then
              break
           end
        end
    end
    return keys
end

local function table_keys_tonum( t )
    local keys = {}
    for k, _ in pairs( t ) do
        if string.sub(k, 1, 1) ~= '_'  then
           keys[#keys + 1] = tonumber(k)
        end
    end
    return keys
end

local function  intersection(ta, tb, n) 
   local inter = {}
   if ta["_objectcount"] <= tb["_objectcount"] then
      for v in pairs( ta) do 
        if string.sub(v, 1, 1) ~= '_' and tb[v] then
             table.insert(inter, tonumber(v))
             if #inter >= n then
                break
             end
        end
      end
   else
      for v in pairs( tb) do 
        if string.sub(v, 1, 1) ~= '_' and ta[v] then
             table.insert(inter, tonumber(v))
             if #inter >= n then
                break
             end
        end
      end
   end
   return inter
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
    table_keys               = table_keys,
    table_keys_tonum         = table_keys_tonum,
    table_keys_first_n       = table_keys_first_n,
    intersection             = intersection,
    is_like                  = is_like
}
return _M

