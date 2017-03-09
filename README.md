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
