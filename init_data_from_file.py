#!/usr/bin/python
import MySQLdb
import sys
import os,re
import json
import urllib
import urllib2
import httplib
import redis
URL = "http://127.0.0.1/pcc"

HOST = "127.0.0.1"
USER = "lgr"
PASSWD = "lgr"
DB = "pcc"

def init_conn():
    conn=MySQLdb.connect(host=HOST,user=USER,passwd=PASSWD,db=DB,port=3306,connect_timeout=15)
    return conn

def read_userdata_from_file(filename):
    datas = []
    with open(filename, "r") as fp:
       while True:
          line = fp.readline()
          if not line:
              break
          line = line.strip()
          if len(line) < 1 or line.startswith("#"):
              continue
          userinfo = line.strip().split(",")
          if len(userinfo) != 2:
             print "format error? %s" % (line)
             continue
          print userinfo 
          datas.append(userinfo)

    return datas
def read_likedata_from_file(filename):
    datas = []
    with open(filename, "r") as fp:
       while True:
          line = fp.readline()
          if not line:
              break
          line = line.strip()
          if len(line) < 1 or line.startswith("#"):
              continue
          infos = line.strip().split(":")
          if len(infos) != 2:
              print "format error? %s" %(line)
              continue
          oid = infos[0]
          like_user = infos[1][1:-1]
          lu = like_user.split(",") 
          print lu 
          for dt in lu:
              datas.append([oid, dt])

    return datas
    
def init_users(filename):
    conn = init_conn()
    cur=conn.cursor()
    users = read_userdata_from_file(filename)
    for userinfo in users:
          uid = userinfo[0]
          name =userinfo[1]
          sql = "insert into users(name) values ('%s')" % (name)
          print sql
          cur.execute(sql)

    conn.commit()
    cur.close()
    conn.close()

def init_friends(url, filename):
    friend_datas = read_userdata_from_file(filename)
    _send_request(url, friend_datas, "friend")

def init_likes(url, filename):
    like_datas = read_likedata_from_file(filename)
    _send_request(url, like_datas, "like")

def _send_request(url, data_list, type):
    httpClient  = httplib.HTTPConnection("127.0.0.1", 8888, timeout=30);
    try:
        headers     = {};
        params      = {};
        for data in data_list:
            if type == "like":
                send_url1 = url + "?action=like&oid=" + data[0] + "&uid=" + data[1]
            elif type == "friend":
                send_url1 = url + "?action=add_friend&friend_id=" + data[1] + "&uid=" + data[0]
            print send_url1
            httpClient.request("GET",send_url1,urllib.urlencode(params),headers);
            response    = httpClient.getresponse();
            print response.status, response.read()
    except Exception, e:
        print 'send failed',str(e)

    if httpClient:
        httpClient.close();

#init_users("data/users.txt")
init_friends(URL, "data/user_friends.txt")
init_likes(URL, "data/object_like.txt")
