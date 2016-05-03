#!/usr/bin/perl -s

use feature 'say' ;

my ($cid,$gr)= (1,0) ;

while (<>)
{
	next unless /\w/ ;

	if ( /\:(\d+)\:(\d+)/ ) { ($cid,$gr)= ($1,$2) ;  say '' ; next }

	@x= grep { $_ } /(\w+)\s+([a-zA-Z\-]+)(?:\s+([a-zA-Z\-]+))?/ ;
	next if $x[0] =~ /^\d/ ;

	my $na= join(' ', map { ucfirst } map { lc } @x ) ;
	my ($gro)= /(\d+)\s*$/ ;
	$gro //= $gr ;

	chomp $na ;
	next unless $na ;

	say "INSERT INTO student SET class_id=$cid, name='$na', grade= $gro ;" ;
}
