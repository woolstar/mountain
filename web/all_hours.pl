#!/usr/bin/perl -s
#

use common::util ;
use common::dbi ( user=> 'school', db => school ) ;
use common::web qw(autoparam entity-encode) ;

my ( $uid, $usr ) ;

&web_main ;

sub get_account
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
}

sub get_hours
{
    my $hct ;
    my $htot ;

    ( $hct, $htot ) = $dbh->selectrow_array("SELECT count(*), sum(value) FROM hours WHERE account_id=$uid and isdel <> 'Y'") ;
    $hash{entries}= $hct ;
    $hash{total}= $htot ;

	my $hidedel ;
	$hidedel= " AND isdel <> 'Y'" unless $query{showdel} ;

    my $hoff= 0 ;
    $hoff= $hct - 20 if $hct > 20 ;
    $hours_= $dbh->selectall_arrayref("SELECT hours_id as id, dt, isdel, typ, value, project, notes FROM hours WHERE account_id=$uid $hidedel ORDER BY 2, 1 LIMIT 500", { Slice => {} }) ;

    $hash{hours}= $hours_ ;

	foreach ( @$hours_ ) {
		if ( 'N' eq $_->{isdel} ) { $_->{del}= 1, $_->{act}= 'X' }
			else { $_->{del}= 0, $_->{act}= "un", $_->{class}= 'del' }
	}
}

sub	do_delete
{
	$query{showdel} ||= 1 unless $query{mode} ;

	my $sql= "UPDATE hours SET isdel= '". ( $query{mode} ? "Y" : "N" ).
		"' WHERE hours_id=$query{del}" ;

	print "DO:\n" . $sql . "\n\n" ;
	dbexec($sql)
}

sub main
{
	&parse_test if $t ;

    $uid= $query{account_id} ;
    $usr= $query{account} ;

    finish('nologin') unless $uid && $usr ;

	get_account($uid, $usr) ;
	&do_delete if $query{del} ;
    &get_hours ;

	return finish('all_hours_sub') if $query{'sub'} ;

    finish('all_hours')
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

