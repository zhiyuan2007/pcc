local _M = {}

local shm_objects = ngx.shared.shm_objects

local OK                = 200
local BEEN_LIKED        = 501
local NO_PARAS_ACTION   = 502
local NO_PARAS_OID      = 503
local NO_PARAS_UID      = 504
local NO_LIKED_UID      = 505
local INSERT_SQL_ERROR  = 506
local NO_PARAS_ISFRIEND = 507  
local NO_PARAS_PAGESIZE = 508  
local UID_NOT_EXISTS    = 510
local NOT_SUPPORT_ACTION = 509

local ERRINFO = {
    [BEEN_LIKED] = "object already been liked.",
    [NO_PARAS_ACTION] = "no paras action",
    [NO_PARAS_OID] = "no paras oid",
    [NO_PARAS_UID] = "no paras uid",
    [NO_LIKED_UID] = "not liked user id",
    [INSERT_SQL_ERROR] = "insert failed, maybe sql format wrong.",
    [NO_PARAS_PAGESIZE] = "no paras page_size",
    [NO_PARAS_ISFRIEND] = "no paras is_friends",
    [NOT_SUPPORT_ACTION] = "not support action",
    [UID_NOT_EXISTS] = "uid not exists"
 }

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

local function response_like(oid, uid, like_list)
    local res = {
                 oid = oid,
                 uid = uid,
                 like_list = like_list
                }
    return cjson.encode(res)
end

local function response_islike(oid, uid, islike)
    local res =  {}
    res["oid"] = oid
    res["uid"] = uid
    res["islike"] = islike
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

local function response_err_msg(oid, uid, error_code)
    local res = {}
    res["oid"] = oid
    res["uid"] = uid
    res["error_code"] = error_code 
    res["error_msg"] = ERRINFO[error_code] 
    return cjson.encode(res)
end

local function check_validity(action, oid, uid, page_size, is_friends) 
    if not action then
        return NO_PARAS_ACTION
    end

    if not oid then
        return NO_PARAS_OID
    end
    
    if action == "like" or action == "is_like" or action == "count" then
       if not uid then
          return NO_PARAS_UID
       end
    elseif action == "list" then
       if not page_size then
           return NO_PARAS_PAGESIZE
       end
       if not is_friends then
           return NO_PARAS_ISFRIEND
       end
    else
       return NOT_SUPPORT_ACTION
    end

    return OK
end


local function  intersection(ta, tb, n) 
   local inter = {}
   if ta["_objectcount"] <= tb["_objectcount"] then
      for v, _ in pairs( ta) do 
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

--------cache result info shared-memory--------
local function _isfriend(uid, fid)
   return shm_objects:get("obj:" .. uid ..":" .. fid)
end
local function _setfriend(uid, fid)
   shm_objects:set("obj:" .. uid ..":" .. fid, true, FRIEND_TTL)
end

local function _islike(oid, uid)
   return shm_objects:get("obj:" .. oid .. uid)
end
local function _existscount(oid)
   return shm_objects:get("count:" .. oid)
end
local function _setislike(oid, uid)
   return shm_objects:set("obj:" .. oid .. uid, 1, IS_TTL)
end
local function _setlikecache(oid, uid, objectlist)
   return shm_objects:set("like:" .. oid .. uid, 1, LIKE_TTL)
end
local function _setcount(oid, c, ttl)
   shm_objects:set("count:" .. oid, c, COUNT_TTL)
end
local function _exitslistwith(oid, uid, page_size, cursor, isfriend)
   return  shm_objects:get("friend:" ..":" .. isfriend .. oid .. ":".. uid .. ":".. cursor ..":".. page_size)
end
local function _setlistwith(oid, uid, page_size, cursor, isfriend, value)
   shm_objects:set("friend:" ..":" .. isfriend .. oid .. ":".. uid .. ":".. cursor ..":".. page_size, value, OBJ_LIST_TTL)
end

local function connect_mysql(server)
     local db, err = mysql:new()
     if not db then
         ngx.say("failed to init mysql: ", err)
         return
     end
     db:set_timeout(1000) -- 1 sec
     local ok, err, errcode, sqlstate = db:connect{
         host = server,
         port = PORT,
         database = DATABASE,
         user = USER,
         password = PASSWORD,
         max_packet_size = 1024 * 1024 }

     if not ok then
        ngx.say("failed to connect:", err, ": ", errcode, " ", sqlstate)
        return
    end  
    return db;
end

local function query_from_mysql(server, sql)

    local db = connect_mysql(server)
    if not db then
        return nil
    end

    res, err, errcode, sqlstate = db:query(sql)
    if not res then
        ngx.say("bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
        return nil
    end
   
    local ok, err = db:set_keepalive(10000, 100)
    if not ok then
	ngx.say("failed to set keepalive: ", err)
        return
    end
    if next(res) ~= nil then
        return res
    end 
    return nil 

end

local function insert_to_mysql(server, oid, uid)

    local db = connect_mysql(server)
    if not db then
        return nil
    end
    
    local sql = "insert into object_likes(oid, uid) values (" .. oid .. "," .. uid .. ")"
    res, err, errcode, sqlstate = db:query(sql)
    if not res then
       if errcode == 1062 then
           goto goonquery
       end
       ngx.log(ngx.WARN, "bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
       return nil
    end

    ::goonquery::
    local sql = "select uid from object_likes where oid = " .. oid 
    res = query_from_mysql(server, sql)
    local ok, err = db:set_keepalive(10000, 100)
    if not ok then
        return nil
    end

    return res

end

local function islike_handler(oid, uid, page_size, is_friends)
   local islike =  _islike(oid, uid)
   if not islike then
        local sql = "select oid, uid from object_likes where oid =" .. oid .. " and uid =" .. uid
        local res = query_from_mysql(ngx.var.server, sql)
        if res then 
           islike = 1
        else 
           islike = 0
        end
   end
   return response_islike(oid, uid, islike)
end

local function count_handler(oid, uid, page_size, is_friends)
   local count =  _existscount(oid)
   if not count then
        local sql = "select count(*) as total  from object_likes where oid =" .. oid 
        local res = query_from_mysql(ngx.var.server, sql)
        if res then 
           count = tonumber(res[1]["total"])
           _setcount(oid, count, COUNT_TTL)
        else
           count = 0
        end
   end
   return response_count(oid, count)  
end

local function _getresult(db_result, idstr, n, typ, cursor) 
     local res = {}
     if typ == "dict" then
         res = {_objectcount = 0}
     end
     local count = 0
     for k, v in pairs(db_result) do
         if count < cursor then
            count = count + 1
            goto endfor
         end
         if typ == "list" then 
            table.insert(res, tonumber(v[idstr])) 
         elseif typ == "dict" then
            res[v[idstr]] = true
            res["_objectcount"] = res["_objectcount"] + 1
         end
         count = count + 1
         if count >= n + cursor then
            break
         end
         ::endfor::
     end
     return res
end

local function _getresultdict(db_result, idstr, n, cursor) 
    return _getresult(db_result, idstr, n , "dict", cursor)
end
local function _getresultlist(db_result, idstr, n, cursor) 
    return _getresult(db_result, idstr, n , "list", cursor)
end

local function list_handler(oid, uid, page_size, is_friends, cursor)
   local result = _exitslistwith(oid, uid, page_size, cursor, is_friends)
   if not result then
       local server = ngx.var.server
       local sql = "select uid from object_likes where oid = " .. oid  .. " limit " .. 5*page_size
       local obj_likes  = query_from_mysql(server, sql)
       if not obj_likes then
           return response_err_msg(oid, uid, NO_LIKED_UID)
       end
       local rtn_like_list = {}
       if is_friends == "1" then -- friend list
           local sql = "select fid from friends where uid = " .. uid 
           local user_friends = query_from_mysql(ngx.var.uid_server, sql)
           
           if user_friends then
               local fri_dict = _getresultdict(user_friends, "fid", page_size, cursor) 
               local obj_dict = _getresultdict(obj_likes, "uid", page_size, cursor) 
               rtn_like_list = intersection(fri_dict, obj_dict, page_size)
           else 
               return response_err_msg(oid, uid, UID_NOT_EXISTS)  
           end
       elseif is_friends == "0" then
           rtn_like_list = _getresultlist(obj_likes, "uid", page_size, cursor) 
       end
       result = response_page_size(oid, rtn_like_list)  
   end  
   _setlistwith(oid, uid, page_size, cursor, is_friends, result)
   return result
end

-----need add lock------
local function like_handler(oid, uid, page_size, is_friends)

   if _islike(oid, uid) then
      _setislike(oid, uid)
      return response_err_msg(oid, uid, BEEN_LIKED) 
   end
   
   --local elapsed, err = insert_lock:lock("insert_db_lock")
   --if not elapsed then
   --    return response_err_msg(oid, uid, 513, "insert failed") 
   --end
   local res = insert_to_mysql(ngx.var.server, oid, uid) 
     
   if not res then
      --insert_lock:unlock()
      return response_err_msg(oid, uid, INSERT_SQL_ERROR) 
   end

   if res then
      _setislike(oid, uid)
   end
   object_likelist = {}
   for k , v in pairs(res) do 
       table.insert(object_likelist, tonumber(v["uid"]))
   end
   --_setlikecache(oid, uid, object_likelist)
  -- insert_lock:unlock()
   return response_like(oid, uid, object_likelist)
end

_M = {
    response_err_msg         = response_err_msg,
    check_validity           = check_validity,
    like_handler             = like_handler,
    islike_handler           = islike_handler,
    count_handler            = count_handler,
    list_handler             = list_handler
}
return _M

