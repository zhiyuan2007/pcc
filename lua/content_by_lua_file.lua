local shm_objects = ngx.shared.shm_objects
local shm_users = ngx.shared.shm_users
local shm_friends = ngx.shared.shm_friends

local OBJECT_PREFIX = "object:"
local COUNT_PREFIX = "count:"
local USER_PREFIX = "user:"

------------obj-tree-------------
------------OBJECT-ROOT----------
--------------/ \----------------
------------O    O---------------
-----------/ \   /\--------------
----------O   O O  O-------------
---------------------------------

----------- user-tree------------
---------------------------------
------------USER-ROOT----------
--------------/ \----------------
------------O    O---------------
-----------/ \   /\--------------
----------O   O O  O-------------
---------------------------------


-------inner function------------

local function _get_objects(oid)
   local object_key = OBJECT_PREFIX .. oid
   local object_likes = shm_objects:get(object_key)
   if object_likes then
       return cjson.decode(object_likes)
   end

   return nil
end

local function _get_userobj(uid)
   local user_key = USER_PREFIX .. uid
   local user_friends = shm_friends:get(user_key)
   if user_friends then
       return cjson.decode(user_friends)
   end
   return nil
end

-----need add lock------
local function like_handler(oid, uid, page_size, is_friends)
   local object_likes = _get_objects(oid)
   if object_likes then
       if object_likes[uid] then
           return common.response_err_msg(oid, uid, 501, "object already been liked.") 
       else
           object_likes[uid] = true
           object_likes['_objectcount'] = object_likes['_objectcount'] + 1
       end
   else
       object_likes = { _objectcount = 1, [uid] = true} 
   end

   shm_objects:set(OBJECT_PREFIX .. oid, cjson.encode(object_likes))
   return common.response_like(oid, uid, common.table_keys_tonum(object_likes))
end


local function islike_handler(oid, uid, page_size, is_friends)
   local islike = 0
   local object_likes = _get_objects(oid)
   if object_likes then
       if object_likes[uid] then
          islike = 1
       end
   end
   return common.response_islike(oid, uid, islike)
end

local function count_handler(oid, uid, page_size, is_friends)
   local count = 0
   local object_likes = _get_objects(oid)
   if object_likes then
       count = object_likes["_objectcount"]
   end
   return common.response_count(oid, count)  
end


local function list_handler(oid, uid, page_size, is_friends)
   local object_likes = _get_objects(oid)
   if object_likes then
       local page_size = tonumber(page_size)
       
       local obj_like_user_cnt = object_likes["_objectcount"] 
       local return_len = page_size <= obj_like_user_cnt and page_size or obj_like_user_cnt
       local rtn_like_list = {}
       if is_friends == "1" then -- friend list
           local user_friends = _get_userobj(uid)
           if user_friends then
               rtn_like_list = common.intersection(object_likes, user_friends, return_len)
           else 
               rtn_like_list = common.table_keys_first_n(object_likes, return_len)
           end
       elseif is_friends == "0" then
           ngx.log(ngx.ERR, "no user and rrrr not is_friends ")
           rtn_like_list = common.table_keys_first_n(object_likes, return_len)
       end
       result = common.response_page_size(oid, rtn_like_list)  
   else
       result = common.response_err_msg(oid, uid, 505, "oid not exists" )  
   end  

   return result
end

local function add_friend_handler(uid, friend_id) 
   local user_friends = _get_userobj(uid)
   if not user_friends then
       user_friends = {[friend_id] = true, _objectcount = 1 }
   else
       if not user_friends[friend_id] then
           user_friends[friend_id] = true
           user_friends["_objectcount"] = user_friends["_objectcount"] + 1
       else
           return common.response_err_msg(friend_id, uid, 507, "friends alreay exists") 
       end
   end
   -----set ----
   shm_friends:set(USER_PREFIX .. uid, cjson.encode(user_friends))
 
   ----return---
   local _friends_list = common.table_keys_tonum(user_friends)
   return cjson.encode({uid = uid, firends = _friends_list})
end

local function build_friendship()
    local uid = ngx.var.arg_uid
    local friend_id = ngx.var.arg_friend_id
    if uid and friend_id then
        return add_friend_handler( uid, friend_id)
    else
        return common.response_err_msg(friend_id, uid, 508, "no uri or friend_id") 
    end
end

-------------------starting--------------------------
local action_handler_obj = {
     ["like"] = like_handler,
     ["is_like"] = islike_handler,
     ["count"] = count_handler,
     ["list"] = list_handler
}

local action = ngx.var.arg_action

----------------add friend--------------------------
if action == "add_friend" then
    build_friendship()
end

local oid = ngx.var.arg_oid 
local uid = ngx.var.arg_uid

---------------check and verify--------------------
local code, msg = common.check_validity(action, oid, uid)
if code >= 500 then
    result = common.response_err_msg(oid, uid, code, msg) 
    ngx.say(result)
    ngx.exit(200)
end

ngx.log(ngx.ERR, "action---", action)
---------------execute handler base on action---------------
current_hander = action_handler_obj[action]
if current_hander then
    result = current_hander(oid, uid, ngx.var.arg_page_size, ngx.var.arg_is_friends)
else
    result = common.response_err_msg(oid, uid, 506, "action not support") 
end

ngx.say(result)
