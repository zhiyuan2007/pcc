local shm_objects = ngx.shared.shm_objects
local shm_users = ngx.shared.shm_users
local shm_friends = ngx.shared.shm_friends

local OBJECT_PREFIX = "object:"
local COUNT_PREFIX = "count:"
local USER_PREFIX = "user:"

local function get_shm_object_key(oid, uid) 
   return "like:" .. oid .. "," .. uid
end

-----need add lock------
local function like_handler(oid, uid, page_size, is_friends)
   local count_key = COUNT_PREFIX .. oid
   local object_key = OBJECT_PREFIX .. oid
   --redis.set(oid, uid)
   local islike = common.is_like(shm_objects, oid, uid)
   if islike then --already exists
       result = common.response_err_msg(oid, uid, 501, "object already been liked.") 
   else --new like
       ----insert user to object liked
       local object_likes = shm_objects:get(object_key)
       if object_likes then
           object_likes = cjson.decode(object_likes)
           table.insert(object_likes, uid)
       else
           object_likes = {uid}
       end
       ----increment user count
       local count = shm_objects:get(count_key)
       if count then 
           shm_objects:incr(count_key, 1)
       else
           shm_objects:set(count_key, 1)
       end
       
       shm_objects:set(object_key, cjson.encode(object_likes))
       shm_objects:set(get_shm_object_key(oid, uid), 1)

       result = common.response_like(oid, uid, object_likes)
   end
   return result
end

local function islike_handler(oid, uid, page_size, is_friends)
   local islike = common.is_like(shm_objects, oid, uid) or 0
   result = common.response_islike(oid, uid, islike)
   return result
end

local function count_handler(oid, uid, page_size, is_friends)
   local count_key = COUNT_PREFIX .. oid
   local count = shm_objects:get(count_key) or 0
   ngx.log(ngx.ERR, "COUNT ---", count)
   result = common.response_count(oid, count)  
   return result
end

local function list_handler(oid, uid, page_size, is_friends)
   local count_key = COUNT_PREFIX .. oid
   local object_key = OBJECT_PREFIX .. oid
   local object_likes = shm_objects:get(object_key)
   if object_likes then
       page_size = tonumber(page_size)
       object_likes = cjson.decode(object_likes)
       return_len = page_size <= #object_likes and page_size or #object_likes
       return_like_list = {}
       for i=1, return_len do
            table.insert(return_like_list, object_likes[i])
       end
       result = common.response_page_size(oid, return_like_list)  
   else
       result = common.response_err_msg(oid, uid, 505, "oid not exists" )  
   end  
end

local function add_friend_handler(uid, friend_id) 
   --- need check repeated---
   local user_key = USER_PREFIX .. uid
   local user_friends = shm_friends:get(user_key)
   ngx.log(ngx.ERR, "friends", tostring(user_friends), "firend is ", friend_id)
   if user_friends then
       user_friends = cjson.decode(user_friends)
       if not user_friends[friend_id] then
           ngx.log(ngx.ERR, "insert", user_friends[friend_id]) 
           user_friends[friend_id] = true
       else
           return common.response_err_msg(friend_id, uid, 507, "friends alreay exists") 
       end
   else
       user_friends = {}
       user_friends[friend_id] = true 
   end
   local _friends_list = common.table_keys(user_friends)
   shm_friends:set(user_key, cjson.encode(user_friends))
   rtn_msg = {} 
   rtn_msg["uid"] = uid
   rtn_msg["friends"] = _friends_list
   result = cjson.encode(rtn_msg)
   return result
end

local action_handler_obj = {
     ["like"] = like_handler,
     ["is_like"] = islike_handler,
     ["count"] = count_handler,
     ["list"] = list_handler
}

local action = ngx.var.arg_action
local oid = ngx.var.arg_oid 
local uid = ngx.var.arg_uid

if action == "add_friend" then
    uid = ngx.var.arg_uid
    friend_id = ngx.var.arg_friend_id
    result = add_friend_handler(uid, friend_id)
    ngx.say(result)
    ngx.exit(200)
end

local code, msg = common.check_validity(action, oid, uid)
if code >= 500 then
    result = common.response_err_msg(oid, uid, code, msg) 
    ngx.say(result)
    ngx.exit(200)
end

ngx.log(ngx.ERR, "action---", action)
--local num1 = ffi_new("uint64_t", 10)
--num = luabit.lshift(num1, 33)
--ngx.log(ngx.ERR, "num---", tonumber(num))
current_hander = action_handler_obj[action]

if current_hander then
    result = current_hander(oid, uid, ngx.var.arg_page_size, ngx.var.arg_is_friends)
else
    result = common.response_err_msg(oid, uid, 506, "action not support") 
end

ngx.say(result)
