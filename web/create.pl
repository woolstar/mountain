#!/usr/bin/perl
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

	my $accid= 0 ;

	&web_main ;

sub main
{
	finish('createform') unless exists $query{lastn} ;

	&valid ;
	finish('accfail') unless $accid ;

	$hash{accid}= $accid ;
	finish('accgo')
}

sub db_test
{
	my ( $q, $err )= @_ ;

	my ($ct)= $dbh-> selectrow_array("SELECT count(*) FROM account WHERE $q") ;
	$hash{fault}= $err if $ct ;
	$ct
}

sub	valid
{
	my ($ln,$fn,$pin,$em, $ds)=
		@hash{qw(lastn firstn pin email desc)}=
		@query{qw(lastn firstn pin email desc)} ;

	$hash{fault}= 'Name blank or invalid' ;
	return unless $ln && $fn ;

	$hash{fault}= 'Pin not two digits' ;
	return unless $pin =~ /(\d\d)/ ;

	my ($qln,$qfn,$qem,$qdesc)= map { $dbh->quote($_) } ( $ln,$fn,$em,$ds) ;
	my ($qpin)= $pin =~ /(\d\d)/ ;
	my $acc= $ln . $qpin ;
	my $qacc= lc $dbh-> quote($acc) ;

	return if db_test("last_name=$qln AND first_name=$qfn", "duplicate name") ;
	return if $em && db_test("str_email=$qem", "email address already used.") ;
	return if db_test("login=$qacc", "account already exists.") ;

	my $sql= "INSERT INTO account SET login=$qacc, last_name=$qln, first_name=$qfn, pin=$qpin, str_email=$qem, str_desc=$qdesc" ;
	dbexec( $sql) ;

	$hash{account}= $acc ;
	( $accid)= $dbh-> selectrow_array("SELECT account_id FROM account WHERE login=$qacc") ;
}

