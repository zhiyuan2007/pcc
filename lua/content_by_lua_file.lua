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

local action_handler_obj = {
     ["like"] = common.like_handler,
     ["is_like"] = common.islike_handler,
     ["count"] = common.count_handler,
     ["list"] = common.list_handler
}

-------------------starting--------------------------

local action = ngx.var.arg_action
local oid = ngx.var.arg_oid 
local uid = ngx.var.arg_uid
local page_size = ngx.var.arg_page_size
local is_friends = ngx.var.arg_is_friends
local friend_id = ngx.var.arg_friend_id

---------------check and verify--------------------
local code, msg = common.check_validity(action, oid, uid, page_size, is_friends, friend_id)
if code >= 500 then
    result = common.response_err_msg(oid, uid, code, msg) 
    ngx.say(result)
    ngx.exit(200)
end

---------------execute handler base on action---------------
local current_hander = action_handler_obj[action]
if current_hander then
    result = current_hander(oid, uid, page_size, is_friends)
else
----------------add friend--------------------------
    if action == "add_friend" then
        result = common.add_friend_handler( uid, friend_id)
    else
        result = common.response_err_msg(oid, uid, 506, "action not support") 
    end
end

ngx.say(result)
