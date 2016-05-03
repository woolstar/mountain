#!/usr/bin/perl -s
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

my ( $uid, $usr ) ;

&web_main ;

sub get_hours
{
    my $hct ;
    my $htot ;

    ( $hct, $htot ) = $dbh->selectrow_array("SELECT count(*), sum(value) FROM hours WHERE account_id=$uid AND isdel <> 'Y'") ;
    $hash{entries}= $hct ;
    $hash{total}= $htot ;

    my $hoff= 0 ;
    $hoff= $hct - 16 if $hct > 16 ;
    $hours_= $dbh->selectall_arrayref("SELECT hours_id, dt, typ, value, project FROM hours WHERE account_id=$uid AND isdel <> 'Y' ORDER BY dt LIMIT 16 OFFSET $hoff", { Slice => {} }) ;

    $hash{hours}= $hours_ ;
}

sub post_hours
{
    my ( $dt, $typ, $val, $proj, $notes)= @query{qw(date typ value proj notes)} ;

    unless ( $dt && $typ && $val ) {
        $hash{hour_err}= "missing required date, type and value" ;
        return ;
    }

    $val= sprintf("%.1f", $val / 5.75) if 'money' eq $typ ;

    my $sql= "INSERT INTO hours SET account_id=$query{account_id}, dt= ?, dtpost=now(), typ= ?, value= ?, project= ?, notes= ?" ;
    dbexec($sql, $dt, $typ, $val, $proj, $notes) ;
}


sub main
{
	&parse_test if $t ;

    $uid= $query{account_id} ;
    $usr= $query{account} ;

    finish('nologin') unless $uid && $usr ;

	&post_hours if 'hour' eq $query{add} ;
    &get_hours ;

    finish('sub_hours')
}

sub	parse_test
{
	my @lst= split(/\&/, $t) ;
	foreach (@lst) {
		my ($k, $v)= /(\w+)\=(.*)/ ;
		print "$k => $v\n" ;
		$query{$k}= $v ;
	}
}

