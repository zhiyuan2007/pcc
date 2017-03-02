local _M = {}

local shm_objects = ngx.shared.shm_objects
local shm_friends = ngx.shared.shm_friends
local USER_PREFIX = "user:"
local OBJECT_PREFIX = "object:"

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
function lua_split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil 
    end 
        
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end 
    return result
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

local function check_validity(action, oid, uid, page_size, is_friends, friend_id) 
    if not action then
        return 502, "no action"
    end
    if action == "add_friend" then
       if uid and friend_id then 
           return 200, "0k"
       end
       return 509, "no uid or friend_id" 
    end

    if not oid then
        return 503, "no oid"
    end
    
    if action == "like" or action == "is_like" or action == "count" then
       if not uid then
          return 504, "no uid" 
       end
       return 200, "ok"
    end
    if action == "list" then
       if page_size and is_friends then
           return 200, "ok"
       end
       return 508, "no page_size or is_friend"
    end

    return 510, "parameter error"
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

local function get_userobj(uid)
   local user_key = USER_PREFIX .. uid
   local user_friends = shm_friends:get(user_key)
   if user_friends then
       return cjson.decode(user_friends)
   end
   return nil
end


local function add_friend_handler(uid, friend_id) 
   local user_friends = get_userobj(uid)
   if not user_friends then
       user_friends = {[friend_id] = true, _objectcount = 1 }
   else
       if not user_friends[friend_id] then
           user_friends[friend_id] = true
           user_friends["_objectcount"] = user_friends["_objectcount"] + 1
       else
           return response_err_msg(friend_id, uid, 507, "friends alreay exists") 
       end
   end
   -----set ----
   shm_friends:set(USER_PREFIX .. uid, cjson.encode(user_friends))
 
   ----return---
   local _friends_list = table_keys_tonum(user_friends)
   return cjson.encode({uid = uid, firends = _friends_list})
end

local function _get_objects(oid)
   local object_key = OBJECT_PREFIX .. oid
   local object_likes = shm_objects:get(object_key)
   if object_likes then
       return cjson.decode(object_likes)
   end

   return nil
end

local function islike_handler(oid, uid, page_size, is_friends)
   local islike = 0
   local object_likes = _get_objects(oid)
   if object_likes then
       if object_likes[uid] then
          islike = 1
       end
   end
   return response_islike(oid, uid, islike)
end

local function count_handler(oid, uid, page_size, is_friends)
   local count = 0
   local object_likes = _get_objects(oid)
   if object_likes then
       count = object_likes["_objectcount"]
   end
   return response_count(oid, count)  
end


local function list_handler(oid, uid, page_size, is_friends)
   local object_likes = _get_objects(oid)
   if object_likes then
       local page_size = tonumber(page_size)
       
       local obj_like_user_cnt = object_likes["_objectcount"] 
       local return_len = page_size <= obj_like_user_cnt and page_size or obj_like_user_cnt
       local rtn_like_list = {}
       if is_friends == "1" then -- friend list
           local user_friends = get_userobj(uid)
           if user_friends then
               rtn_like_list = intersection(object_likes, user_friends, return_len)
           else 
               rtn_like_list = table_keys_first_n(object_likes, return_len)
           end
       elseif is_friends == "0" then
           rtn_like_list = table_keys_first_n(object_likes, return_len)
       end
       result = response_page_size(oid, rtn_like_list)  
   else
       result = response_err_msg(oid, uid, 505, "oid not exists" )  
   end  

   return result
end
-----need add lock------
local function like_handler(oid, uid, page_size, is_friends)
   local object_likes = _get_objects(oid)
   if object_likes then
       if object_likes[uid] then
           return response_err_msg(oid, uid, 501, "object already been liked.") 
       else
           object_likes[uid] = true
           object_likes['_objectcount'] = object_likes['_objectcount'] + 1
       end
   else
       object_likes = { _objectcount = 1, [uid] = true} 
   end

   shm_objects:set(OBJECT_PREFIX .. oid, cjson.encode(object_likes))
   return response_like(oid, uid, table_keys_tonum(object_likes))
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
    add_friend_handler       = add_friend_handler,
    get_userobj              = get_userobj,
    like_handler             = like_handler,
    islike_handler           = islike_handler,
    count_handler            = count_handler,
    list_handler             = list_handler,
    is_like                  = is_like
}
return _M

