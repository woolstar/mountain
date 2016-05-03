#!/usr/bin/perl -s
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

	my ( $accid, $nlast, $nfirst, $ndesc ) ;
	my ( @memb ) ;
	my ( $hours_ ) ;
	my ( $classes_ ) ;

	&web_main ;

sub	get_account
{
	my ( $ui, $u)= @_ ;
	( $accid, $nlast, $nfirst, $ndesc)= $dbh->selectrow_array(
				"SELECT account_id, last_name, first_name, str_desc FROM account
					WHERE login= '$u' and account_id='$ui' and isactive='T'
				") ;


	return unless $accid ;

	$hash{account_id}= $accid ;
	$hash{account}= $u ;
	@hash{qw(strlast strfirst strdesc)}= ( $nlast, $nfirst, $ndesc ) ;

	$hash{students}=
		$dbh-> selectall_arrayref("SELECT student_id, class_id, name FROM family_member JOIN student USING ( `student_id`) WHERE account_id=$accid AND isactive='Y' ORDER BY member_id", { Slice => {} } ) ;

}

sub	get_hours
{
	my $hct ;
	my $htot ;

	( $hct, $htot ) = $dbh->selectrow_array("SELECT count(*), sum(value) FROM hours WHERE account_id=$accid AND isdel <> 'Y' ") ;
	$hash{entries}= $hct ;
	$hash{total}= $htot ;

	my $hoff= 0 ;
	$hoff= $hct - 16 if $hct > 16 ;
	$hours_= $dbh->selectall_arrayref("SELECT hours_id, dt, typ, value, project FROM hours WHERE account_id=$accid AND isdel <> 'Y' ORDER BY dt LIMIT 16 OFFSET $hoff", { Slice => {} }) ;

	$hash{hours}= $hours_ ;
}

sub	get_classes
{
	$classes_= $dbh->selectall_arrayref(
					"SELECT class_id, desc_grade, desc_teacher FROM class ORDER BY 1",
					{ Slice => {} } ) ;

	my $r_ = {} ;
	foreach ( @$classes_ )
		{ $r_->{$_->{class_id}}= "$_->{desc_grade} : $_->{desc_teacher}" }
	$hash{grades}= $r_ ;

	my %cls ;
	my $sql= "SELECT class_id, student_id, name FROM school.student ORDER BY 1, 2" ;
	my $sth= dbexec($sql) ;
	while ( my ( $cid, $sid, $nam )= $sth-> fetchrow_array )
		{ push @{$cls{$cid}}, "[ $sid, '$nam' ]" }

	$hash{classes}= join(",\n",
		map { "$_ : [ ". join(",\n", @{$cls{$_}}). "]" } keys %cls
		) ;
}

sub main
{
	&parse_test if $t ;

	my $uid= $query{account_id} ;
	my $usr= $query{account} ;

	finish('nologin') unless $uid && $usr ;

	&post_hours if 'hour' eq $query{add} ;
	&post_member if 'member' eq $query{add} ;

	get_account( $uid, $usr) ;

	&get_hours ;
	&get_classes ;

	foreach ( @{$hash{students}} )
		{ $_->{'classna'}= $hash{grades}->{$_->{class_id}} }

	my $now= t_to_datetime( time()) ;
	$hash{now}= substr($now, 0, 10) ;

	finish('main')
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

sub	post_hours
{
	my ( $dt, $typ, $val, $proj, $notes)= @query{qw(date typ value proj notes)} ;

	unless ( $dt && $typ && $val ) {
		$hash{hour_err}= "missing required date, type and value" ;
		return ;
	}

	$val= sprintf("%.1f", $val / 5.75) if 'money' eq $typ ;

	my $sql= "INSERT INTO hours SET account_id=$query{account_id}, dt= ?, typ= ?, value= ?, project= ?, notes= ?" ;
	dbexec($sql, $dt, $typ, $val, $proj, $notes) ;
}

sub post_member
{
	my ( $gr, $sid)= @query{qw(grade student)} ;

	return unless $sid ;

	my $sql= "INSERT IGNORE INTO family_member SET account_id= ?, student_id= ?" ;
	dbexec($sql, $query{account_id}, $sid) ;
}

