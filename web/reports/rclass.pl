#!/usr/bin/perl -s
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

use Data::Dumper ;

	my ($classes_, $fam_, $hours_) ;

	&web_main ;

sub	get_classes
{
	$classes_= $dbh->selectall_hashref(
					"SELECT class_id, desc_grade, desc_teacher FROM class ORDER BY 1",
					'class_id'
					) ;
}

sub get_families
{
	my $classlst_= $dbh-> selectall_arrayref(
					"SELECT class_id, COUNT(DISTINCT student_id) AS ct, GROUP_CONCAT(DISTINCT name) AS stu FROM student NATURAL JOIN family_member GROUP BY 1",
					{ Slice => {} } ) ;

	foreach my $f ( @$classlst_ ) {
		my $c_= $classes_->{$f->{class_id}} ;
		$c_->{count}= $f->{ct} ;
		$c_->{students}= $f->{stu} ;
	}

	my $famclass_= $dbh-> selectall_arrayref("SELECT account_id, GROUP_CONCAT(DISTINCT class_id) FROM student NATURAL JOIN family_member GROUP BY 1") ;
	foreach ( @$famclass_ ) {
		my ( $aid, $famlist )= @$_ ;
		$fam_->{$aid}= [ split /,/, $famlist ]
	}
}

sub get_hours
{
	my $sth= dbexec("SELECT account_id, sum(value) FROM hours WHERE isdel <> 'Y' GROUP BY 1") ;
	while ( my ( $aid, $v )= $sth-> fetchrow_array ) {

		# print "blip: $aid $v\n" ;

		foreach ( @{$fam_->{$aid}} ) {
			$classes_->{$_}{hours} += $v ;
		}
	}
}

sub main
{
	&get_classes ;
	&get_families ;
	&get_hours ;

	$hash{row}= [ map { $classes_->{$_} } sort { $a <=> $b } keys %$classes_ ] ;
	# $hash{dump}= "classes: " . Dumper($classes_) . "\n" ;

	finish('rclass')
}

sub parse_test
{
	my @lst= split(/\&/, $t) ;
	foreach (@lst) {
		my ($k, $v)= /(\w+)\=(.*)/ ;
		print "$k => $v\n" ;
		$query{$k}= $v ;
	}
}

