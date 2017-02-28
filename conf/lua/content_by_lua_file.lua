local shm_objects = ngx.shared.shm_objects

local function get_shm_object_key(oid, uid) 
   return "like:" .. oid .. "," .. uid
end

local function check_validity(action, oid, uid) 
    if not action then
        ngx.say("no action")
        ngx.exit(200)
    end
    if not oid then
        ngx.say("no oid")
        ngx.exit(200)
    end
    
    if action == "like" or action == "islike" then
       if not uid then
          ngx.say("no uid")
          ngx.exit(200)
       end
    end
end

local action = ngx.var.arg_action
local oid = ngx.var.arg_oid 
local uid = ngx.var.arg_uid

check_validity(action, oid, uid)

result = ""
ngx.log(ngx.ERR, "-----")

if action == "like" then
   --redis.set(oid, uid)
   shm_objects:set(get_shm_object_key(oid, uid), uid)
   ngx.log(ngx.ERR, "1-----")
   result = common.response_like(oid, uid)
   ngx.log(ngx.ERR, "2-----")
elseif action == "islike" then
   local islike = common.is_like(shm_objects, oid, uid)
   result = common.response_islike(oid, uid, islike)
elseif action == "count" then
   result = common.response_count(oid, 1)  
elseif action == "page_size" then
   result = common.response_page_size(oid, {1, 2})  
end
ngx.say(result)
