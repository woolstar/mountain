

use POSIX;
use Time::Local;

umask 0002;

$benchmark_start_time = time;

$main::hash{lib_version} = strip_version('$Name:  $');

chop($hostname = qx[hostname]) unless $hostname;

{
    chomp(my $pwd = qx[pwd]);
    my @x = split(/\//, "$pwd/$0");
    do
    {
	($program) = (pop @x) =~ /^(.*?)(?:\..*)?$/;
    }
    while ($program =~ /(?:^$|^index\b|^process\b)/);
}


sub cmd
{
    my($cmd) = @_;
    my $ret = system($cmd);
    # check return code
    # $ret & 0x7f => died due to signal, so die
    # $ret & 0x80 => $ret == 255 => died due to die, so die
    if ($ret & 0x807f)
    {
	my(undef, $name, $line) = caller;
	$! = $? = 0;
	die "Died at $name, line $line: $cmd\n";
    }
    int($ret >> 8);
}

sub cmdlog
{
    syslog('info', @_);
    &cmd;
}

sub syslog
{
    my $fatal = $_[0] eq 'err';

    if (1)
    {
        my $level = uc shift;
        my($sec, $min, $hour, $day, $mon) = localtime;
        my $text = sprintf "%s %2d %02d:%02d:%02d $hostname $program\[$$]: $level:", (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$mon], $day, $hour, $min, $sec;
        print "$text @_\n";
    }
    else
    {
        Sys::Syslog::syslog(@_);
    }

    die "Fatal.\n" if $fatal;
}


sub parseArgs
{
    my %named = @_;
    my(%switch); @switch{@{$named{switch}}} = undef;
    my($argc);

    %ARG = ();

    for (my $i = 0; $i < @ARGV; $i++)
    {
	if ($ARGV[$i] =~ /^\--(.*?)(?:=(.*?))?$/)
	{
	    my($key, $val) = ($1, $2);
	    if (defined $val)
	    {
		$ARG{$key} = $val;
	    }
	    elsif (! defined $val)
	    {
		if (exists $switch{$key})
		{
		    $ARG{$key} = 1;
		}
		else
		{
		    die "missing --$key argument\n" if $#ARGV < $i + 1 ||  $ARGV[$i + 1] =~ /^\-/;
		    $ARG{$key} = $ARGV[++$i];
		}
	    }

	    print "$key -> ${$key}\n" if $test;
	}
	elsif ($ARGV[$i] =~ /^\-(.*?)$/)
	{
	    my($s) = ($1);

	    die "-$s: bad switch\n" if $s !~ /^[0-9a-z]+$/;

	    for my $ch (split(//, $s))
	    {
		$ARG{$ch}++;
	    }

	    print "$ch -> ${$ch}\n" if $test;
	}
	else
	{
	    $ARGV[$argc++] = $ARGV[$i];
	}
    }

    splice(@ARGV, $argc);
}


sub load_file
{
    my($filename, $data) = @_;
    local($/, *IN);
    if (open(IN, $filename))
    {
        $data = <IN>;
        close IN;
    }
    $data;
}

# save a file
# Dies if it can't write the file (e.g., No space left on device).

sub save_file
{
    my($filename, @data) = @_;
    local(*FH);
    ### ### make the path as necessary ###
    if ($filename !~ /^\s*[\|\>]/)
    {
        my @path = split(/\//, $filename);
        pop @path;
        my($path);
        for (@path)
        {
            $path .= "$_/";
            unless (-d $path)
            {
                mkdir $path || die "$path: $!";
            }
        }
    }
    $filename = ">$filename" unless $filename =~ /^\s*[\|\>]/;
    if (open(FH, $filename))
    {
        my $data = join('', @data);
	my $wrote = syswrite FH, $data;
        close FH;
        return if $wrote == length($data);
	die "$filename: short write (wrote $wrote bytes, needed @{[length($data)]}\n";
    }
    die "$filename: $!\n";
}


sub cq
{
    my($s) = @_;
    $s =~ s/\'/\'\\\'\'/g;
    $s;
}


sub curlq
{
    my($s) = @_;
    $s =~ s/\'/\'\\\'\'/g;
    $s =~ s/\ /\+/g;
    $s;
}


sub fetch
{
    my($url, $timeout) = @_;
    my $hash = $timeout;
    if (ref $hash eq "HASH")
    {
	$timeout = $hash->{timeout} if exists $hash->{timeout};
    }
    else
    {
	$hash = {};
    }
    (my $fn = $url) =~ s/\//_/sg;
    $fn = "data/cache/$fn";
    print STDERR "mtime=@{[(stat $fn)[9]]} > cutoff=@{[time - $timeout]}\n" if $hash->{verbose} && defined $timeout;
    my $data = load_file($fn) if defined $timeout && (stat $fn)[9] > time - $timeout;
    return $data if length($data);
    print STDERR "fetching $url (timeout=$timeout)\n" if $hash->{verbose};

    my($cookies, $ua, $referer, $maxtime);

    if (exists $hash->{ua})
    {
	$ua = "-A '" . curlq($hash->{ua} || $ENV{HTTP_USER_AGENT}) . "'";
    }

    if ($hash->{referer})
    {
	$referer = "-H 'Referer: $hash->{referer}'";
    }

    if ($hash->{maxtime})
    {
	$maxtime = "-m $hash->{maxtime}";
    }

    if ($hash->{cookies} || $hash->{cook})
    {
	mkdir "data";
	$cookies = "-b data/cookies.txt -c data/cookies.txt";

	if ($hash->{cook})
	{
	    qx[curl --silent $ua $referer $maxtime -c data/cookies.txt --location -H "Accept-Encoding: gzip,deflate" --compressed '@{[curlq($url)]}'];
	}
    }
    # Accept-Encoding deals with IIS which sends a gzip file and a deflate header.  This one requests that it simply send gzip, and the header matches.
    my $data = qx[curl --silent $ua $referer $maxtime $cookies --location -H "Accept-Encoding: gzip,deflate" --compressed '@{[curlq($url)]}'];
    save_file($fn, $data) if defined $timeout;
    $data;
}


sub block
{
    my($html, $elt, $depth, $want, $subtract) = @_;

    $depth |= 1;
    $want ||= $elt;

    $html =~ s/<script.*?<\/script>//isg;
    my @x = split(/(<$elt|<\/$elt>)/is, $html);

    my $nest = 0;
    my(@a, $found, @html, @sub);

    @html = $html if $subtract;

    for (my $i = 0; $i < @x; $i++)
    {
	if ($x[$i] =~ /^<$elt/is)
	{
	    print "a[$nest] <= $x[$i]\n" if $v;
	    push @a, $i;
	}
	elsif ($x[$i] =~ /^<\/$elt/is)
	{
	    if ($found && $found - @a + 1 == $depth)
	    {
		if ($subtract)
		{
		    pop @sub if @sub && $sub[$#sub]->[$i] > $a[$#a];
		    push @sub, [$a[$#a], $i];
		    #@html = join("", @x[0..$a[$#a] - 1], @x[$i + 1..$#x]);
		    #last;
		}
		else
		{
		    push @html, join("", @x[$a[$#a]..$i]);
		}
		undef $found;
	    }
	    pop @a;
	}
	if ($x[$i] =~ /$want/i)
	{
	    $found = @a if @a >= $depth;
	    print "found=$found\n" if $v;
	}
    }

    if (@sub)
	{
		for (reverse @sub)
		{
			splice(@x, $_->[0], $_->[1] - $_->[0]);
		}

		@html = join("", @x);
	}

	push @html, $html =~ /(<$elt [^>]*?$want.*?>.*?)\s*</xis unless @html ;

    return @html if wantarray;
    join("", @html);
}


#sub block
#{
#    my($html, $elt, $depth, $want, $subtract) = @_;
#
#    $depth |= 1;
#    $want ||= $elt;
#
#    $html =~ s/<script.*?<\/script>//isg;
#    my @x = split(/(<$elt|<\/$elt>)/is, $html);
#
#    my $nest = 0;
#    my(@a, $found, @html);
#
#    @html = $html if $subtract;
#
#    for (my $i = 0; $i < @x; $i++)
#    {
#	if ($x[$i] =~ /^<$elt/is)
#	{
#	    print "a[$nest] <= $x[$i]\n" if $v;
#	    push @a, $i;
#	}
#	elsif ($x[$i] =~ /^<\/$elt/is)
#	{
#	    if ($found && $found - @a + 1 == $depth)
#	    {
#		if ($subtract)
#		{
#		    @html = join("", @x[0..$a[$#a] - 1], @x[$i + 1..$#x]);
#		    last;
#		}
#		push @html, join("", @x[$a[$#a]..$i]);
#		undef $found;
#	    }
#	    pop @a;
#	}
#	if ($x[$i] =~ /$want/i)
#	{
#	    $found = @a if @a >= $depth;
#	    print "found=$found\n" if $v;
#	}
#    }
#
#    return @html if wantarray;
#    join("", @html);
#}


#sub block
#{
#    my($html, $elt, $depth, $want) = @_;
#
#    $depth |= 1;
#    $want ||= $elt;
#
#    $html =~ s/<script.*?<\/script>//isg;
#    my @x = split(/(<$elt|<\/$elt>)/is, $html);
#
#    my $nest = 0;
#    my(@a, @b, $found, @html);
#
#    for (my $i = 0; $i < @x; $i++)
#    {
#	if ($x[$i] =~ /^<$elt/is)
#	{
#	    print "a[$nest] $x[$i]\n" if $v;
#	    $a[$nest++] = $i;
#	}
#	elsif ($x[$i] =~ /^<\/$elt/is)
#	{
#	    $b[--$nest] = $i;
#	    print "b[$nest] $x[$i]\n" if $v;
#	    if ($found)
#	    {
#		if ($found - $nest == $depth)
#		{
#		    print "nest=$nest\n" if $v;
#		    push @html, join("", @x[$a[$nest]..$b[$nest]]);
#		    undef $found;
#		}
#	    }
#	}
#	if ($x[$i] =~ /$want/i)
#	{
#	    $found = $nest if $nest >= $depth;
#	    print "found=$found\n" if $v;
#	}
#    }
#
#    return @html if wantarray;
#    join("", @html);
#}


sub time_suffix_to_minutes
{
    my($z) = @_;
    return int($1 / 60) if $z =~ /^(\d+)s$/i;
    return $1 if $z =~ /^(\d+)m$/i;
    return 60 * $1 if $z =~ /^(\d+)h$/i;
    return 24 * 60 * $1 if $z =~ /^(\d+)d$/i;
    return 7 * 24 * 60 * $1 if $z =~ /^(\d+)w$/i;
    $z;
}


sub time_suffix_to_hours
{
    my($z) = @_;
    int(time_suffix_to_minutes($z) / 60);
}


sub t_to_datetime
{
    my($t, $tz) = @_;
    $tz ||= 'UTC';
    local $ENV{TZ} = $tz; tzset();
    my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($t);
    sprintf "%04d-%02d-%02d %02d:%02d:%02d", 1900 + $year, $mon + 1, $mday, $hour, $min, $sec;
}


sub datetime_to_t
{
    my($datetime, $tz) = @_;

    my($y, $m, $d, $h, $min, $sec, $zulu) = $datetime =~ /^(\d\d\d\d)-(\d\d)(?:-(\d\d)(?:[ T](\d\d):(\d\d)(?::(\d\d))?(Z?))?)?$/;

    $tz = 'UTC' if $zulu;
    $tz ||= 'UTC';

    local $ENV{TZ} = $tz; tzset();
    $d ||= '01';
    $arg{debug} .= "dt=$datetime\n" unless 1 <= $m && $m <= 12;
    return unless 1 <= $m && $m <= 12;
    timelocal($sec, $min, $h, $d, $m - 1, $y);
}


*dt2t = *datetime_to_t;
*t2dt = *t_to_datetime;


sub tzadjust
{
    my($date, $stz, $dtz) = @_;
    # return undef so that frgmt() can be used as a display filter
    # and not cause the Boopsie portal rendering to fail
    return unless $date && $date ne "0000-00-00 00:00:00" && $stz && $dtz;
    die "date=$date  stz=$stz  dtz=$dtz\n" unless $date && $stz && $dtz;
    t2dt(dt2t($date, $stz), $dtz);
}

sub togmt
{
    my($date, $tz) = @_;
    $tz ||= $hash{_tz} || PST8PDT;
    tzadjust($date, $tz, UTC);
}

sub frgmt
{
    my($date, $tz) = @_;
    $tz ||= $hash{_tz} || PST8PDT;
    tzadjust($date, UTC, $tz);
}


sub mm::ss
{
    my($s) = @_;
    my $m = int($s / 60); $s -= 60 * $m;
    my $z = sprintf("%02d:%02d", $m, int($s));
    $z =~ s/^00/  /;
    $z;
}


sub hh::mm::ss
{
    my($s) = @_;
    my $h = int($s / 3600); $s -= 3600 * $h;
    my $m = int($s / 60); $s -= 60 * $m;
    my $z = sprintf("%02d:%02d:%02d", $h, $m, int($s));
    $z =~ s/^00:(?:00)?//;
    $z;
}


sub hms
{
    my($x);

    for (@_)
    {
        my($s) = $_;

        $x .= "  " if $x;
        $x .= "-" if $s < 0;

        $s = abs($s);

        my $y = int($s / (365.25 * 24 * 60 * 60)); $s -= 365.25 * 24 * 60 * 60 * $y;
        my $d = int($s / (24 * 60 * 60)); $s -= 24 * 60 * 60 * $d;
        my $h = int($s / (60 * 60)); $s -= 60 * 60 * $h;
        my $m = int($s / 60); $s -= 60 * $m;
        $s = int($s);

        $x .= "@{[commas($y)]}y " if $y;
        $x .= "${d}d " if $d;# || $y;
        $x .= "${h}h " if $h;# || $y || $d;
        $x .= "${m}m " if $m;# || $y || $d || $h;
        $x .= "${s}s"  if $s;# || $y || $d || $h || $m;
    }

    $x;
}

sub ago
{
    my $ago = time - dt2t(@_, GMT);
    return "@{[hms($ago)]} ago" if $ago > 0;
    return "@{[hms(-$ago)]} to go" if $ago < 0;
    return "now";
}

sub commas
{
    my($s) = @_;
    1 while $s =~ s/^(.*\d)(\d\d\d)/$1,$2/;
    $s;
}

sub benchmark
{
    my($name) = @_;
    my $sec = time - $benchmark_start_time;
    $hash{benchmark} .= " &nbsp; $name: ${sec}s";
    $benchmark_start_time = time;
}

sub     strip_version
{
        my ($str)= @_;

        return '-' unless $str =~ /v(\d\d)(\d\d)(\d\d\d\d)/;
        sprintf "v %d.%d <FONT size=1>(%04d)</FONT>", $1, $2, $3;
}

sub		param_str
{
	my ($s) ;

	my @lst= sort keys %query ;
	local $"= ',' ;
	$s= "Q @lst\n\n" ;
	foreach ( @lst) { $s .= "  $_: $query{$_}\n" }

	$s
}

1;

