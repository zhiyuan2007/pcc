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
    Latency   109.43ms  236.80ms   1.26s    86.99%
    Req/Sec     2.57k   322.97     6.25k    77.31%
  1227324 requests in 30.10s, 269.04MB read
Requests/sec:  40775.43
Transfer/sec:      8.94MB
</pre>

<pre>
count 接口，uid和oid都是随机的。
Running 30s test @ http://192.168.153.122:8888/pcc
  16 threads and 600 connections
1  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   131.04ms  258.88ms   1.05s    84.85%
    Req/Sec     3.39k   701.97     9.48k    82.87%
  1615964 requests in 30.10s, 319.17MB read
Requests/sec:  53685.75
Transfer/sec:     10.60MB
</pre>

<pre>
list 接口，uid和oid都是随机的。
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
