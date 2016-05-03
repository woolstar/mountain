#!/usr/bin/perl -s
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

use Data::Dumper ;

	my ($famlist_) ;

	&web_main ;

sub	get_list
{
	my $sth= dbexec("SELECT year(dt), month(dt), COUNT(DISTINCT account_id) AS ct, SUM(value) AS val FROM hours WHERE isdel <> 'Y' GROUP BY 1, 2 ") ;

	my @r= () ;

	while ( my ($dy,$dm, $ct,$v)= $sth-> fetchrow_array )
		{ push @r, { dt => sprintf("%04d-%02d", $dy, $dm), vol => $ct, hours => $v } }

	$hash{row}= \@r ;

	finish('rtop_cal')
}

sub get_top
{
	$famlist_= $dbh-> selectall_arrayref(
		"SELECT account_id, last_name, first_name, SUM(value) as val
			FROM hours NATURAL JOIN account
		    WHERE dt BETWEEN '$query{date}' and '$query{date}' + interval 1 month AND isdel <> 'Y'
			GROUP BY 1 ORDER BY val DESC LIMIT 15",
				{ Slice => {} } 
		) ;

	$hash{date}= $query{date} ;
}

sub trim
{
	return unless @$famlist_ > 9 ;

	my $cutoff= $famlist_->[9]{val} ;
	while ( $famlist_->[-1]{val} < $cutoff )
		{ pop @$famlist_ }
}

sub sort_name
{
	foreach ( @$famlist_ ) { 
		$_->{name}= ( ucfirst $_->{first_name} ) . " " . ucfirst $_->{last_name} ;
		$_->{last_name}= lc $_->{last_name}, $_->{first_name}= lc $_->{first_name} ;
	}

	$famlist_= [ sort { $a->{last_name} cmp $b->{last_name} || $a->{first_name} cmp $b->{first_name} }
					@$famlist_
				]
}

sub main
{
	&parse_test if $t ;

	return &get_list unless $query{date} ;

	&get_top ;
	&trim ;
	&sort_name ;

	$hash{row}= $famlist_ ;
	# $hash{dump}= "names: " . Dumper($famlist_) . "\n" ;

	finish('rtop_list')
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

