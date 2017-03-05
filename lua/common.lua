local _M = {}

local shm_objects = ngx.shared.shm_objects
local shm_friends = ngx.shared.shm_friends
local shm_input_queue = ngx.shared.shm_queue
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

local function response_err_msg(oid, uid, error_code, error_msg)
    local res = {}
    res["oid"] = oid
    res["uid"] = uid
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

local function get_userobj(uid)
   local user_key = USER_PREFIX .. uid
   local user_friends = shm_friends:get(user_key)
   if user_friends then
       return cjson.decode(user_friends)
   end
   return nil
end


local function _isfriend(uid, fid)
   return shm_objects:get("obj:" .. uid ..":" .. fid)
end
local function _setfriend(uid, fid)
   shm_objects:set("obj:" .. uid ..":" .. fid, true, FRIEND_TTL)
end

local function _get_objects(oid)
   local object_key = OBJECT_PREFIX .. oid
   local object_likes = shm_objects:get(object_key)
   if object_likes then
       return cjson.decode(object_likes)
   end

   return nil
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

local function testmsg(msg)
        ngx.say(msg) 
        ngx.exit("200")
end

local function connect_mysql(server)
     local db, err = mysql:new()
     if not db then
         ngx.say("failed to instantiate mysql: ", err)
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
        ngx.say("failed to connect------: ", err, ": ", errcode, " ", sqlstate)
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
   
    --res = cjson.encode(res)
    
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
local function insert_user_to_mysql(server, uid, fid)

    local db = connect_mysql(server)
    if not db then
        return nil
    end
    
    local sql = "insert into friends(uid, fid) values (" .. uid .. "," .. fid .. ")"
    res, err, errcode, sqlstate = db:query(sql)
    if not res then
       if errcode == 1062 then
           return true
       end
       ngx.log(ngx.WARN, "bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
       return nil
    end

    --ngx.log(ngx.ERR, res.affected_rows, " rows inserted into table cats ", "(last insert id: ", res.insert_id, ")")

    local ok, err = db:set_keepalive(10000, 100)
    if not ok then
        return nil
    end

    return res

end

local function insert_friend_to_mysql(server, uid, fid)

    local db = connect_mysql(server)
    if not db then
        return nil
    end
    
    local sql = "insert into friends(uid, fid) values (" .. uid .. "," .. fid .. ")"
    res, err, errcode, sqlstate = db:query(sql)
    if not res then
       if errcode == 1062 then
           res = 1
           goto goonquery
       end
       ngx.log(ngx.WARN, "bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
       return nil
    end

    ::goonquery::
    return res
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
    --ngx.log(ngx.ERR, res.affected_rows, " rows inserted into table cats ", "(last insert id: ", res.insert_id, ")")

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
           --res = cjson.decode(res)
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
           return response_err_msg(oid, uid, "505", "no like user")
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
               return response_err_msg(oid, uid, 505, "uid not exists")  
           end
       elseif is_friends == "0" then
           rtn_like_list = _getresultlist(obj_likes, "uid", page_size, cursor) 
           --rtn_like_list = table_keys_first_n(object_likes, return_len)
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
      return response_err_msg(oid, uid, 501, "object already been liked.") 
   end
   
   --local elapsed, err = insert_lock:lock("insert_db_lock")
   --if not elapsed then
   --    return response_err_msg(oid, uid, 513, "insert failed") 
   --end
   local res = insert_to_mysql(ngx.var.server, oid, uid) 
     
   if not res then
      --insert_lock:unlock()
      return response_err_msg(oid, uid, 502, "insert failed, myby format table wor.") 
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

-----need add lock------
local function batch_like_handler(oid, uid_input, page_size, is_friends)
   local object_likes = _get_objects(oid)
   if not object_likes then
       object_likes = {_objectcount = 0}
   end 
   uid_list = lua_split(uid_input, ",")
   for _, uid in pairs(uid_list) do
        if object_likes[uid] then
           ngx.log(ngx.WARN, "repeated ", uid, "oid ", oid, "str ", uid_input) 
        else
           object_likes[uid] = true
           object_likes['_objectcount'] = object_likes['_objectcount'] + 1
        end
   end

   local ok, err = shm_objects:set(OBJECT_PREFIX .. oid, cjson.encode(object_likes))
   if err then
       ngx.log(ngx.ERR, "safe set error : ", err)
       return common.response_err_msg(oid, uid, 512, err) 
   end
   return response_like(oid, "0", table_keys_tonum(object_likes))
end
local function add_friend_handler(uid, fid) 
   if _isfriend(uid, fid) then
      return response_err_msg(oid, uid, 501, "object already been liked.") 
   end
   
   local res = insert_friend_to_mysql(ngx.var.uid_server, uid, fid) 
   if not res then
      return response_err_msg(oid, uid, 501, "insert failed. may exitsts") 
   end
   if res then
      _setfriend(uid, fid)
   end
   return response_err_msg(fid, uid, 200, "object insert success.") 
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
    batch_like_handler       = batch_like_handler,
    is_like                  = is_like
}
return _M

