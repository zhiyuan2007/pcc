curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=add_friend\&uid=3\&friend_id=4
echo 'should--------------------------->{"uid":3,"friends":[4]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=add_friend\&uid=3\&friend_id=2
echo 'should--------------------------->{"uid":3,"friends":[2,4]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=add_friend\&uid=3\&friend_id=1
echo 'should--------------------------->{"uid":3,"friends":[2,4,1]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=add_friend\&uid=2\&friend_id=3
echo 'should--------------------------->{"uid":2,"friends":[3]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=add_friend\&uid=2\&friend_id=1
echo 'should--------------------------->{"uid":2,"friends":[3,1]}'

curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=like\&uid=3\&oid=2
echo 'should--------------------------->{"oid":2,"uid":3,"like_list":[3]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=like\&uid=1\&oid=2
echo 'should--------------------------->{"oid":2,"uid":1,"like_list":[3,1]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=like\&uid=1\&oid=1
echo 'should--------------------------->{"oid":1,"uid":1,"like_list":[1]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=like\&uid=3\&oid=1
echo 'should--------------------------->{"oid":1,"uid":3,"like_list":[1,3]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=like\&uid=2\&oid=1
echo 'should--------------------------->{"oid":1,"uid":3,"like_list":[1,3,2]}'

curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=is_like\&uid=3\&oid=2
echo 'should--------------------------->{"oid":2,"islike":1,"uid":3}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=is_like\&uid=4\&oid=2
echo 'should--------------------------->{"oid":2,"islike":0,"uid":4}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=is_like\&uid=3\&oid=1
echo 'should--------------------------->{"oid":2,"islike":1,"uid":3}'

curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=count\&uid=3\&oid=2
echo 'should--------------------------->{"oid":2,"count":2}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=count\&uid=3\&oid=1
echo 'should--------------------------->{"oid":1,"count":3}'

#uid:3->1,2,4
#uid:2->3,1
#oid:2->1,3
#oid:1->1,2,3
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=list\&uid=3\&oid=2\&page_size=10\&is_friends=1
echo 'should--------------------------->{"oid":2,"like_list":[1]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=list\&uid=3\&oid=2\&page_size=10\&is_friends=0
echo 'should--------------------------->{"oid":2,"like_list":[1,3]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=list\&uid=3\&oid=1\&page_size=10\&is_friends=1
echo 'should--------------------------->{"oid":1,"like_list":[1,2]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=list\&uid=2\&oid=1\&page_size=10\&is_friends=1
echo 'should--------------------------->{"oid":1,"like_list":[1,3]}'
curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=list\&uid=3\&oid=1\&page_size=10\&is_friends=0
echo 'should--------------------------->{"oid":1,"like_list":[1,2,3]}'

curl -x 127.0.0.1:8888 http://127.0.0.1/pcc?action=list\&uid=8\&oid=1\&page_size=2\&is_friends=0
echo 'should--------------------------->{"oid":1,"like_list":[1,3]}'
