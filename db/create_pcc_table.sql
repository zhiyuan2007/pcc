--#user table
--#object table
--#user relationship table
--#object_liked table

CREATE TABLE `users` (
`uid` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
`name` varchar(255) NOT NULL,
 PRIMARY KEY (`uid`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `objects` (
`oid` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
`name` varchar(1024) NOT NULL,
 PRIMARY KEY (`oid`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `friends` (
`id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
`uid` bigint(20) unsigned NOT NULL,
`fid` bigint(20) unsigned NOT NULL,
 PRIMARY KEY (`id`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `object_like` (
`id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
`oid` bigint(20) unsigned NOT NULL,
`uid` bigint(20) unsigned NOT NULL,
 PRIMARY KEY (`id`)
)ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

--grant all privileges on *.* to lgr@"%" identified by 'lgr';
--flush privileges;


