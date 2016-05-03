use     Time::Local ;

package main ;

       #####

sub format_seconds
{
    my ($t)= @_ ;
    ($t >= 60 * 60) ? hh::mm::ss($t) : mm::ss($t)
}

sub convert_datestr
{
    my ($dt)= @_ ;
    return '' unless $dt =~ /(\d+)\/(\d+)\/(\d+)/ ;
    sprintf "20%02d-%02d-%02d 00:00:00", $3, $1, $2 ;
}

sub convert_when
{
    my ($dt)= @_ ;

    return datetime_to_t(convert_datestr($dt)) ;
}

sub generate_dayrange
{
    my ($t, $tl)= @_ ;
    my @retlist ;

    local $ENV{TZ}= "PST8PDT" ;  tzset() ;

    while ($t <= $tl)
    {
        my (undef, undef, undef, $td, $tm, $ty)= localtime($t) ;
        $tm += 1;
        push @retlist, { date => sprintf( "%04d-%02d-%02d", 1900+$ty, $tm, $td), showdate => "$tm/$td" } ;
        $t += 24 * 60 * 60 ;
    }

    return @retlist ;
}

	####

sub isleap
{
    my ($y) = @_ ;

    ( ! ( $y % 4 ) && (( $y % 100 ) || ( ! ( $y % 400 ) ) ) )
}

sub ylength
{
    my ($y) = @_ ;

    (isleap($y) ? 366 : 365) ;
}

sub when_to_j
{
    my ($str)= @_ ;
    if ( $str =~ /(\d+)\/(\d+)\/(\d+)/ ) { return date_to_j(2000 + $3, $1, $2) ; }
    0 ;
}
sub db_to_j
{
    my ($str)= @_ ;
    if ( $str =~ /(\d{4})-(\d\d)-(\d\d)/ ) { return date_to_j($1, $2, $3) ; }
    0 ;
}

sub date_to_j
{
    my ($y, $m, $d)= @_ ;
    my @marr= (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334) ;

    my $j = $d ;
    $j += $marr[$m-1] ;
    $j ++ if ($m > 2) && isleap($y) ;

    while ($y > 2000) { $j += isleap( -- $y ) ? 366 : 365 ; }
    $j ;
}

sub j_to_date
{
    my ($j)= @_ ;
    my ($y, $m, $d)= (2000, 1, 0) ;
    my @monthl= (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31) ;

    while ($j > ylength($y)) { $j -= ylength($y ++) ; }
    $monthl[2] ++ if isleap($y) ;

    while ( $j > $monthl[$m] ) { $j -= $monthl[$m ++] ; }
    $d= $j ;

    wantarray ? ($y, $m, $d) : sprintf( "%04d-%02d-%02d", $y, $m, $d ) ;
}

sub t_to_hms
{
    my ($t)= @_ ;
    my ($s,$m,$h,$mh) ;
    $s= $t % 60 ;
    $mh= ($t - $s) / 60 ;
    $m= $mh % 60 ;
    $h= ($mh - $m) / 60 ;

    wantarray ? ($h, $m, $s) : sprintf("%02d:%02d:%02d", $h, $m, $s) ;
}

sub hms2t
{
    my ($hms)= @_ ;
    my ($h,$m,$s)= $hms =~ /(\d+)\:(\d+)\:(\d+)/ ;
    (($h * 60) + $m) * 60 + $s
}

	####

## determine_range
##   use a combination of $beg/$end/$window/$back/today to determine a start and finish

sub	determine_range
{

    if ( $beg ) {
	unless ( $end ) {
	    $window ||= 1 ;
	    $end= j_to_date(db_to_j($beg) +$window) ;
	}
    }
    else
    {
	$back ||= 2 ;
	$end= substr(t_to_datetime( time ), 0, 10) ;
	$beg= j_to_date(db_to_j($end) - $back) ;
    }
}

	####

sub db_to_pair
{
    my ($str)= @_ ;

    if ( $str =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ )
        { return ( date_to_j($1, $2, $3), ((( $4 * 60 ) + $5 ) * 60 + $6) ) ; }

    (0, 0) ;
}

sub db_to_range
{
    my ($v1, $v2)= @_ ;

    my ($d1, $t1)= db_to_pair($v1) ;
    my ($d2, $t2)= db_to_pair($v2) ;

    my ($tend, $dt, @ans) ;
    $tend= 24 * 60 * 60 ;

    while ($d1 < $d2) {
        $dt= $tend - $t1 ;
        push @ans, { date => $d1, t => $t1, e => $tend, dur => $dt } ;
        $d1 ++, $t1= 0 ;
    }

    $t2= $t1 if $t2 < $t1 ;
    push @ans, { date => $d2, t => $t1, e => $t2, dur => $t2 - $t1 } ;

    @ans
}

sub db_to_bare
{
    my ($str, $tz)= @_ ;
    $str= tzadjust($str, undef, $tz) if $tz && $tz ne 'UTC' ;
    my ($dy,$dm,$dd,$th,$tm,$ts)= $str =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ ;

    ("$dy$dm$dd", "$th$tm$ts", $th)
}

1;



