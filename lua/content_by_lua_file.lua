
-------------------starting--------------------------

local args ={}
if "GET" == ngx.req.get_method() then
　　args = ngx.req.get_uri_args()
elseif "POST" == ngx.req.get_method() then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end 
local action = args["action"] 
local oid = args["oid"]
local uid = args["uid"]
local page_size = args["page_size"]
local is_friends = args["is_friends"]
local cursor = args["cursor"]
ngx.log(ngx.ERR, "action: ", action,  " oid : " , oid, "uid:",  uid, "method", ngx.req.get_method())
---local action = ngx.var.arg_action
---local oid = ngx.var.arg_oid 
---local uid = ngx.var.arg_uid
---local page_size = ngx.var.arg_page_size
---local is_friends = ngx.var.arg_is_friends
---local cursor = ngx.var.arg_cursor
if not cursor then
    cursor = 0
else
    cursor = tonumber(cursor)
end
local fid = ngx.var.arg_fid

---------------check and verify--------------------
local code, msg = common.check_validity(action, oid, uid, page_size, is_friends, fid)
if code >= 500 then
    result = common.response_err_msg(oid, uid, code, msg) 
    ngx.say(result)
    ngx.exit(200)
end

oid = tonumber(oid)
uid = tonumber(uid)
page_size = tonumber(page_size)
if oid then
    ngx.var.server = SERVER[oid % 3 + 1]
end
if uid then
   ngx.var.uid_server = SERVER[uid % 3 + 1]
end

---------------execute handler base on action---------------
local current_hander = action_handler_obj[action]
if current_hander then
    result = current_hander(oid, uid)
else
----------------add friend--------------------------
    if action == "add_friend" then
        result = common.add_friend_handler( uid, fid)
    elseif action == "list" then
        result = common.list_handler(oid, uid, page_size, is_friends, cursor)
    else
        result = common.response_err_msg(oid, uid, 506, "action not support") 
    end
end

ngx.say(result)
