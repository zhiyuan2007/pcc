
-------------------starting--------------------------

local args ={}
if "GET" == ngx.req.get_method() then
€€ args = ngx.req.get_uri_args()
elseif "POST" == ngx.req.get_method() then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end 
local oid = args["oid"]
local uid = args["uid"]
local action = args["action"] 
local cursor = args["cursor"]
local page_size = args["page_size"]
local is_friends = args["is_friends"]
ngx.log(ngx.ERR, "action: ", action,  " oid : " , oid, "uid:",  uid, "method", ngx.req.get_method())

cursor = cursor and tonumber(cursor) or 0

local fid = ngx.var.arg_fid

---------------check and verify--------------------
local code = common.check_validity(action, oid, uid, page_size, is_friends)
if code > 200 then
    result = common.response_err_msg(oid, uid, code) 
    ngx.say(result)
    ngx.exit(200)
end

oid = tonumber(oid)
uid = tonumber(uid)
page_size = tonumber(page_size)
if oid then
    ngx.var.server = SERVER[oid % #SERVER + 1]
end
if uid then
   ngx.var.uid_server = SERVER[uid % #SERVER + 1]
end

---------------execute handler base on action---------------
local current_hander = action_handler_obj[action]
if current_hander then
    result = current_hander(oid, uid)
else
    result = common.list_handler(oid, uid, page_size, is_friends, cursor)
end

ngx.say(result)
