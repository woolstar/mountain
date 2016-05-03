
create user school ;

create database school ;

USE school ;

GRANT ALL on * TO school ;
GRANT ALL on * TO 'school'@'localhost' ;

~ switch users

DROP TABLE class ;

CREATE TABLE class (
		`class_id` int(11) unsigned NOT NULL auto_increment,
		`desc_grade` varchar(64) NOT NULL default '',
		`desc_teacher` varchar(64) NOT NULL default '',
		`name` varchar(96) NOT NULL default '',
		PRIMARY KEY (`class_id`)
		)
ENGINE=MyISAM ;

DROP TABLE student ;

CREATE TABLE student (
		`student_id` int(11) unsigned NOT NULL auto_increment,
		`class_id` int(11) unsigned NOT NULL default 0,
		`name` varchar(96) NOT NULL default '',
		`grade` int(11) unsigned NOT NULL,
	PRIMARY KEY (`student_id`)
	)
	ENGINE=MyISAM ;

INSERT INTO class SET desc_grade='Kindergarten', desc_teacher='Ms. Karen', name='Karen McNamara' ;
INSERT INTO class SET desc_grade='Grade 1', desc_teacher='Ms. Gina', name='Gina Andress' ;
INSERT INTO class SET desc_grade='Grade 2', desc_teacher='Ms. Mary', name='Mary Cagigas' ;
INSERT INTO class SET desc_grade='Grade 3', desc_teacher='Ms. Julie', name='Julie Frost' ;
INSERT INTO class SET desc_grade='Grade 4', desc_teacher='Ms. Joni', name='Joni Wojcik' ;
INSERT INTO class SET desc_grade='Grade 5', desc_teacher='Ms. Susan', name='Susan Spizzirri' ;
INSERT INTO class SET desc_grade='Grade K-1', desc_teacher='Ms. Anna', name='Anna Jaconi' ;
INSERT INTO class SET desc_grade='Grade 2-3', desc_teacher='Ms. Gretchen', name='Gretchen Stetter' ;
INSERT INTO class SET desc_grade='Grade 4-5', desc_teacher='Ms. Marsha', name='Marsha Thompson' ;

DROP TABLE account ;
DROP TABLE family_member ;

CREATE TABLE account (
	`account_id` int(11) unsigned NOT NULL auto_increment,
	`login` varchar(16) NOT NULL default '',
	`last_name` varchar(64) NOT NULL default '',
	`first_name` varchar(64) NOT NULL default '',
	`pin` varchar(4) NOT NULL,
	`str_phone` varchar(32),
	`str_email` varchar(128),
	`str_desc` varchar(256),
	`isactive` ENUM('F','T') NOT NULL DEFAULT 'T',
	`issingle` ENUM('N','Y') NOT NULL DEFAULT 'N',
	PRIMARY KEY (`account_id`, `login` ),
	KEY `klog` (`login`)
	)
	ENGINE=MyISAM ;

CREATE TABLE family_member (
	`member_id` int(11) unsigned NOT NULL auto_increment,
	`account_id` int(11) unsigned NOT NULL,
	`student_id` int(11) unsigned NOT NULL,
	`isactive` ENUM('N','Y') NOT NULL DEFAULT 'Y',
	PRIMARY KEY (`member_id`),
	UNIQUE KEY `kaccount` (`account_id`, `student_id`)
	)
	ENGINE=MyISAM ;


DROP TABLE hours ;

CREATE TABLE hours (
		`hours_id` int(11) unsigned NOT NULL auto_increment,
		`account_id` int(11) unsigned NOT NULL,
		`dt` date NOT NULL,
		`dtpost` datetime NOT NULL,
		`typ` ENUM('hours', 'money') NOT NULL default 'hours',
		`isdel` ENUM('N','Y') NOT NULL DEFAULT 'N',
		`value` varchar(8) NOT NULL default '0',
		`project` varchar(128),
		`notes` text,
	PRIMARY KEY (`hours_id`),
	KEY `kaccount` (`account_id`,`isdel`)
	)
	ENGINE=MyISAM ;


INSERT INTO account SET login='test0', last_name='smith', first_name='john', pin='0',
				str_desc='Test account' ;

INSERT INTO hours SET account_id=1, dt='2013-08-29', dtpost=now(), value='1', project='test', notes='burning time just doing a test' ;

