#!/usr/bin/perl -s
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

use Data::Dumper ;

	my ($famlist_) ;

	&web_main ;

sub get_accounts
{
	my %hrs= @{ $dbh-> selectcol_arrayref(
		"SELECT account_id, SUM(value) FROM hours WHERE isdel <> 'Y' GROUP BY 1",
			{ Columns => [1, 2] })
		} ;
	$famlist_= $dbh-> selectall_arrayref(
		"SELECT account_id, login, last_name, first_name FROM account ORDER BY last_name, first_name",
				{ Slice => {} } 
		) ;

	foreach ( @$famlist_ ) { $_->{hours}= $hrs{$_->{account_id}} }
}

sub process_name
{
	foreach ( @$famlist_ )
		{ $_->{name}= ( ucfirst $_->{first_name} ) . " " . ucfirst $_->{last_name} }
}

sub main
{
	&parse_test if $t ;

	&get_accounts ;
	&process_name ;

	$hash{row}= $famlist_ ;
	# $hash{dump}= "names: " . Dumper($famlist_) . "\n" ;

	finish('radmin')
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

