# pcc
performance challenge champion

# 说明
##
  这是高性能挑战赛一道题目，因为要达到30wqps，任何数据库，NOSQL，都不可能实现这个目标
  最能想到的方法就是缓存，把业务数据缓存起来，然后直接应答，这是解决高性能的思考
##
  机器配置为：8核cpu，16G内存。因为以上的思考，所以没用redis等内存数据库，
  因为内存有限，数据量庞大，如果使用内存数据库存储，那么用于缓存的内存肯定更少,
##
  所以架构是，采用mysql存储数据,SSD存储，采用openresty实现业务逻辑，同时把从数据库得到的结果缓存到nginx的共享内存里，
  每次响应请求，都是先查缓存，有数据就直接返回，没有数据则查数据库。
  
-------
由于数据量过大，只有一台测试机，实际导入了284236000条用户好友数据，293097380条对象被关注数据。


功能测试如下： 
<pre>

[root@client2 wrk-4.0.2]# curl "http://192.168.153.122:8888/pcc?action=like&uid=162342&oid=4807868"
{"oid":4807868,"uid":162342,"like_list":[162341,162342]}
[root@client2 wrk-4.0.2]# curl "http://192.168.153.122:8888/pcc?action=is_like&uid=162342&oid=4807868"
{"oid":4807868,"islike":1,"uid":162342}
[root@client2 wrk-4.0.2]# curl "http://192.168.153.122:8888/pcc?action=count&uid=162342&oid=4807868"
{"oid":4807868,"count":2}
[root@client2 wrk-4.0.2]# curl "http://192.168.153.122:8888/pcc?action=list&uid=162342&oid=4807868&page_size=100&is_friends=0"
{"oid":4807868,"like_list":[162341,162342]}

</pre>

性能测试如下：mysql cpu 500%, nginx 8个进程都是80%多。测试机器一共16核，但是nginx启动了8个进程。


<pre>
is_like 接口，uid和oid都是随机的。
[root@client2 wrk-4.0.2]# wrk -d 30s -c 600 -t 16  -s scripts/post.lua  "http://192.168.153.122:8888/pcc" 
Running 30s test @ http://192.168.153.122:8888/pcc
  16 threads and 600 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   124.41ms  250.84ms   1.49s    85.60%
    Req/Sec     2.70k   434.99     7.46k    78.34%
  1282231 requests in 30.10s, 281.25MB read
Requests/sec:  42598.88
Transfer/sec:      9.34MB
</pre>

<pre>
[root@client2 wrk-4.0.2]# wrk -d 30s -c 600 -t 16  -s scripts/post.lua  "http://192.168.153.122:8888/pcc" 
Running 30s test @ http://192.168.153.122:8888/pcc
  16 threads and 600 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   133.15ms  260.79ms   1.03s    84.58%
    Req/Sec     3.88k     0.89k   10.77k    83.93%
  1842985 requests in 30.10s, 363.39MB read
Requests/sec:  61229.32
Transfer/sec:     12.07MB
</pre>

<pre>
list 接口，uid和oid都是随机的。is_friends=0
[root@client2 wrk-4.0.2]# wrk -d 30s -c 600 -t 16  -s scripts/post.lua  "http://192.168.153.122:8888/pcc" 
Running 30s test @ http://192.168.153.122:8888/pcc
  16 threads and 600 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   137.70ms  261.30ms   1.55s    84.70%
    Req/Sec     2.25k   399.80     9.10k    79.64%
  1066803 requests in 30.10s, 274.44MB read
Requests/sec:  35443.28
Transfer/sec:      9.12MB
</pre>

<pre>
list 接口，uid和oid都是随机的。is_friends=0
[root@client2 wrk-4.0.2]# wrk -d 30s -c 600 -t 16  -s scripts/post.lua  "http://192.168.153.122:8888/pcc" 
Running 30s test @ http://192.168.153.122:8888/pcc
  16 threads and 600 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   139.54ms  263.65ms   1.32s    84.39%
    Req/Sec     2.30k   365.12     7.42k    75.81%
  1096630 requests in 30.10s, 278.29MB read
Requests/sec:  31432.77
Transfer/sec:      9.25MB

</pre>

<pre>
post.lua 脚本内容如下：
wrk.method = "POST"
wrk.body    = nil
wrk.headers["Content-Type"] = "application/x-www-form-urlencoded"

local i = 0
request = function()
    uid = i % 10000000;
    oid = i % 30000000; 
    --qs = "action=count&oid="..oid.."&uid="..uid
    --qs = "action=is_like&oid="..oid.."&uid="..uid
    --qs = "action=list&oid="..oid.."&uid="..uid .. "&page_size=100&is_friends=0&cursor=0"
    qs = "action=list&oid="..oid.."&uid="..uid .. "&page_size=100&is_friends=1&cursor=0"
    local body = wrk.format(nil, nil, nil, qs)
    i = i + 1
    return body
end

</pre>
