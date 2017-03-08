--#drop database pcc;
create database pcc;

use pcc;

drop table if exists `users`;
drop table if exists `objects`;
drop table if exists `object_like`;
drop table if exists `object_likes`;
drop table if exists `friends`;

CREATE TABLE `users` (
`uid` bigint(32) unsigned NOT NULL ,
`name` varchar(255) NOT NULL,
 PRIMARY KEY (`uid`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `objects` (
`oid` bigint(32) unsigned NOT NULL ,
`name` varchar(1024) NOT NULL,
 PRIMARY KEY (`oid`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `friends` (
`id` bigint(32) unsigned NOT NULL AUTO_INCREMENT,
`uid` bigint(32) unsigned NOT NULL,
`fid` bigint(32) unsigned NOT NULL,
 PRIMARY KEY (`id`),
 UNIQUE indexuid (`uid`),
CONSTRAINT ou_id UNIQUE (`uid`,`fid`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `object_likes` (
`id` bigint(32) unsigned NOT NULL AUTO_INCREMENT,
`oid` bigint(32) unsigned NOT NULL,
`uid` bigint(32) unsigned NOT NULL,
 PRIMARY KEY (`id`),
 index indexoiduid (`oid`, `uid`),
CONSTRAINT ou_id UNIQUE (`oid`,`uid`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

grant all privileges on *.* to pcc@"192.168.0.%" identified by 'pcc';
grant all privileges on *.* to pcc@"localhost" identified by 'pcc';
flush privileges;
