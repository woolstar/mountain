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
INSERT INTO class SET desc_grade='Kindergarten - 1/2 day', desc_teacher='Ms. Helen', name='Helen Schulz' ;
INSERT INTO class SET desc_grade='Grade 1-2', desc_teacher='Ms. Nicole', name='Nicole Dissinger' ;
INSERT INTO class SET desc_grade='Grade 3-4', desc_teacher='Ms. Marsha', name='Marsha Thompson' ;
INSERT INTO class SET desc_grade='Grade 5-6', desc_teacher='Ms. Gretchen', name='Gretchen' ;
INSERT INTO class SET desc_grade='Grade 1', desc_teacher='Ms. Gina', name='Gina Andress' ;
INSERT INTO class SET desc_grade='Grade 2', desc_teacher='Ms. Mary', name='Mary Cunningham' ;
INSERT INTO class SET desc_grade='Grade 3', desc_teacher='Ms. Julie Frost', name='Julie Frost' ;
INSERT INTO class SET desc_grade='Grade 4', desc_teacher='Ms. Joni', name='Joni Wojcik' ;
INSERT INTO class SET desc_grade='Grade 5', desc_teacher='Ms. Susan', name='Susan Spizzirri' ;

DROP TABLE family_member ;

CREATE TABLE family_member (
	`member_id` int(11) unsigned NOT NULL auto_increment,
	`account_id` int(11) unsigned NOT NULL,
	`student_id` int(11) unsigned NOT NULL,
	`isactive` ENUM('N','Y') NOT NULL DEFAULT 'Y',
	PRIMARY KEY (`member_id`),
	UNIQUE KEY `kaccount` (`account_id`, `student_id`)
	)
	ENGINE=MyISAM ;

