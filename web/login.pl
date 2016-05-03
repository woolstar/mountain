#!/usr/bin/perl
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

	&web_main ;

sub main
{
	my $usr= lc $query{account} ;

	my ( $accid ) = $dbh->selectrow_array("SELECT account_id FROM account WHERE login='$usr' AND isactive='T' ") ;

	finish('nologin') unless $accid ;

	$hash{accid}= $accid ;
	$hash{account}= $usr ;

	finish('fwd')
}

