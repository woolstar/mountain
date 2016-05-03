#!/usr/bin/perl


use common::util;
use common::rewrite ;

$server_name = $ENV{SERVER_NAME} || "host.boopsie.com";


sub common::web::import
{
    # Import options:
    #  verbose - be verbose
    #  -print - do not tie print
    #  -query - do not parse query string nor content
    #  -gzip - do not gzip output
    #  autoparm - bind hash and query
    #  entity-encode - entity-encode by default
    #  guard-blocks - don't substitute into javascript, etc. blocks

    my(%opt);
    for (@_)
    {
	my $x = $_;
	$x =~ s/\-/\_/g;
	$opt{$x} = undef;
    }

    # initialize globals, so that SpeedyCGI (and mod_perl?) works
    %hash = ();
    if (!exists $opt{_nocache})
    {
	@set_headers = (
			"Cache-Control: no-cache",
			"Pragma: no-cache",
			"Expires: -1",
			);
    }

    *hash = *query unless exists $opt{_autoparm};
    $no_gzip = exists $opt{_gzip};
    $entity_encode_by_default = !exists $opt{_entity_encode};
    $guard_blocks = exists $opt{guard_blocks};

    $tie_stdout = !exists $opt{"-print"} && exists $ENV{QUERY_STRING};
    tie *STDOUT, "Print" if $tie_stdout;

    $save_output = exists $opt{save_output};

    if (! exists $opt{_query})
    {
	die if $ENV{CONTENT_LENGTH} > 5_000_000;

        read(STDIN, my $content, $ENV{CONTENT_LENGTH}) if $ENV{CONTENT_LENGTH};
        if ($ENV{CONTENT_TYPE} =~ /^multipart\/form-data; boundary=(.*)$/is)
        {
            %query = parse_query($ENV{QUERY_STRING});

            my($boundary) = ($1);
            while ($content =~ /$boundary(.*?)--(?=$boundary)/sg)
            {
                my($part) = ($1);
                my($head, $body) = $part =~ /^\r?\n(.*?\r?\n)\r?\n(.*?)\r?\n$/s;

                #print "$head\n";

                my($type);

                if ($head =~ /^Content-Type:\s*(.*?)\r?$/im)
                {
                    $type = $1;
                }

                if ($head =~ /\bname="(.*?)"(?:;\s*filename="(.*?)")?/g)
                {
                    my($name, $filename) = ($1, $2);
                    $query{$name} = $body;
                    $qvery{$name}{filename} = $filename if $filename;
                    $qvery{$name}{type} = $type if $type;
                    if (exists $opt{verbose})
                    {
                        print "$name=@{[length($body) > 20? length($body): $body]}\n";
                        for (sort keys %{$qvery{$name}})
                        {
                            print "\t$_ $qvery{$name}{$_}\n";
                        }
                    }
                }
            }
        }
        else
        {
	    # Added REQUEST_URI here because mod_rewrite wasn't forwarding the query_string
	    # It was an issue for facebook flavor
	    # - it should be fixed there instead
	    my($request) = $ENV{REQUEST_URI} =~ /\?(.*)$/;
	    %query = parse_query($request, $ENV{QUERY_STRING}, $content);
	}
    }
}


package Print;

sub TIEHANDLE
{
    my($i);
    bless \$i, shift;
}

sub PRINT
{
    my $this = shift;
    $main::hash{debug} .= join("", @_);
}

sub PRINTF
{
    my $this = shift;
    my $format = shift;
    $main::hash{debug} .= sprintf $format, @_;
}

package main;


sub parse_query
{
    my($hint, %query);

    for (@_)
    {
        next if ref $_ eq "HASH";

        for (split(/&/))
        {
            my($key, $value);
            if (/^(.*?)=(.*)$/)
            {
                ($key, $value) = (decode_url($1), decode_url($2));
		next if $value eq "- select -";
            }
            else
            {
                ($key, $value) = (decode_url($_), 1);
            }
            $query{$key} = $value;
            $qwery{$key}->{$value} = undef;
        }
    }

    %query;
}


sub encode_url
{
    my($s) = @_;
    $s =~ s/([\x00-\x2f\#\%\&\'\+\/\=\:\?\x80-\xff])/"%".uc unpack(H2,$1)/ge;
    #$s =~ s/\s/+/g;
    $s;
}

sub decode_url
{
    my($s) = @_;
    $s =~ s/\+/ /g;
    $s =~ s/%(..)/pack(H2,$1)/ge;
    $s;
}

*eu = *encode_url;
*du = $decode_url;

sub encode_field
{
    my($s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/\"/&quot;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s;
}

sub decode_field
{
    my($s) = @_;
    $s =~ s/&#(\d+);/pack(C,$1)/eg;
    $s =~ s/&gt;/>/g;
    $s =~ s/&lt;/</g;
    $s =~ s/&quot;/\"/g;
    $s =~ s/&amp;/&/g;
    $s;
}


sub gen_document
{
    my($name, $hash) = @_;
    $name =~ s/[^_0-9a-z]+//gi;
    my $template = load_template('head') . load_template($name) . load_template('tail');

    $hash->{_name} ||= ucfirst $name || 'empty';
    delete @$hash{qw(_refresh_tag _refresh_indicator)};
    $hash{versions} = $hash{app_version} . " / " . $hash{lib_version} ;
    if ($hash->{_refresh})
    {
        $hash->{_refresh_tag} = "<meta http-equiv=refresh content=\"$hash->{_refresh}\">";
        $hash->{_refresh_indicator} = "auto refresh: $hash->{_refresh} sec";
    }
    gen_html($template, $hash);
}

sub include
{
    my($name, $hash) = @_;
    $name =~ s/[^_0-9a-z]+//gi;
    gen_html(load_template($name), $hash || \%hash);
}

sub load_template
{
    my($name) = @_;
    return load_file("html/$name.html") if -r "html/$name.html";
    load_file("common/html/$name.html");
}


sub gen_html
{
    my($template, $hash) = @_;
    my($result);

    my @template = split(/(<repeat.*?<\/repeat>)/isg, $template);

    $hash->{_standout} = <<EOF;
<table bgcolor=#ff0000 cellspacing=1 cellpadding=1><tr><td>
<table width=550 bgcolor=#ffeeee><tr><td>
EOF
    $hash->{'/_standout'} = <<EOF;
</td></tr></table>
</td></tr></table>
EOF

    #if (0)
    {
	if ($dbh)
	{
	    ($hash->{_now}) = $dbh->selectrow_array('select now()');
	}
	else
	{
	    my($s, $m, $h, $da, $mo, $ye) = gmtime;
	    $hash{_now} = sprintf "%d-%02d-%02d %02d:%02d:%02d", 1900 + $ye, 1 + $mo, $da, $h, $m, $s;
	}

        #my($sec, $min, $hour, $day, $mon, $year) = localtime;
        #$hash->{_now} = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $day, $hour, $min, $sec);
    }

    for my $template (@template)
    {
        if (my($key, $replicant) = $template =~ /<repeat\s+on=(\S+)>\s*(.*?)<\/repeat>/isg)
        {
	    my @replicant = split(/<repeat\/?>/, $replicant);
            my $rowary = $hash->{$key};
            my $count = $hash->{"$key._count"} = @$rowary;

	    my(@key);

            for (my $i = 0; $i < $count; $i++)
            {
		@$hash{@key} = undef;
                $hash->{"$key._i0"} = $i;
                $hash->{"$key._i"} = $i + 1;

                my $rowref = $rowary->[$i];

                if (ref $rowref eq 'HASH')
                {
                    for my $col (keys %$rowref)
                    {
			my $x = "$key.$col";
                        $hash->{$x} = $rowref->{$col};
			push @key, $x;
                    }
                }
                elsif (ref $rowref eq 'ARRAY')
                {
                    my @col = @{$hash->{"$key._column"}};
                    print "$key: missing $key._column specification\n" unless @col;

                    for (my $i = 0; $i < @col; $i++)
                    {
			my $x = "$key.$col[$i]";
                        $hash->{$x} = $rowref->[$i];
			push @key, $x;
                    }
                }

                $result .= substitute_hash($replicant[$i % @replicant], $hash);
            }
        }
        else
        {
            $result .= substitute_hash($template, $hash);
        }
    }

    $result;
}

sub generate_html
{
    my($filename, $name, $hash) = @_;
    save_file($filename, gen_document($name, $hash));
}


sub web_run
{
    my $cref = shift || \&main;
    $throw_success++;
    eval {$cref->(@_)};
    if ($@ !~ /^Success/)
    {
	print $@ if $@;
	if ($hash{content_type} eq "text/plain")
	{
	    output($hash{debug});
	}
	else
	{
	    $hash{content_type} = "text/html";
	    finish();
	}
    }
}

*web_main = *web_run;

sub finish
{
    my($name, $hash) = @_;
    $hash ||= \%hash;
    $hash{content_type} ||= "text/html";
    $hash->{content_type} ||= "text/html";
    my $html = gen_document($name, $hash);
    output($html);

    die "Success\n" if $throw_success;
}


sub output
{
    my $data = join('', @_);
    $hash{content_type} ||= "text/html";

    if (!$no_gzip && length($data) > 10240)
    {
	my $zfn = "/tmp/gzip$$.dat";
	save_file("|gzip >$zfn", $data);
	$data = load_file($zfn);
	unlink $zfn;
	push @set_headers, "Content-Encoding: gzip";
    }

    untie *STDOUT if $tie_stdout;

    my $output = $data;
    if (exists $ENV{QUERY_STRING})
    {
	$output = join("\r\n", "Content-Type: $hash{content_type}", @set_headers, "Content-Length: @{[length($data)]}", undef, $data);
    }
    save_file("work.html", $output) if $save_output;
    print $output;

    tie *STDOUT, 'Print' if $tie_stdout;

    die "Success\n" if $throw_success;
}


sub forward
{
    save_file(">>/tmp/forward", "here\n");
    my($s, $hash) = @_;
    $hash ||= \%hash;

    $s .= "&error=" . encode_url($hash->{error}) if $hash->{error};
    $s .= "?" . join('&', map {"$_=@{[encode_url($hash->{$_})]}"} keys %$hash) unless $s =~ /\?/;

    if ($hash->{debug})
    {
        $hash->{_next} = $s;
        return finish('forward_debug', $hash);
    }

    untie *STDOUT if $tie_stdout;
    # Why doesn't 
    #   print join("\n", "Location: $s", @set_headers, undef);
    # work??
    print join("\n", "Status: 302", "Location: $s", @set_headers), "\n\n";

    die "Success\n" if $throw_success;
}


sub substitute_hash
{
    my($template, $hash) = @_;

    $template =~ s/<option list>{(.+?)}<\/option>/gen_options($hash->{$1})/ge;
    $template =~ s/{(\S+?)=(select .+?)}/gen_select($1, $2)/ge;
    $template =~ s/{(checked|selected)\s+if\s+(.*?)=(.*?)}/@{[$hash->{$2} eq $3? $1: ""]}/g;
    if ($guard_blocks)
    {
	$template =~ s/((?:<script.*?<\/script>|<style.*?<\/style>))|{(.*?)}/$1 || substitute_one_item($2, $hash)/igse;
    }
    else
    {
	$template =~ s/{(\S.*?)}/substitute_one_item($1, $hash)/ge;
    }

    $template;
}

sub substitute_one_item
{
    my($item, $hash) = @_;

    my($encoding, $guts, $close) = $item =~ /^([\"\%\&\<])?(.*?)([\"\%\&\>])?$/;

    $close =~ s/^>$/</;
    $hash{tail_debug} .= "substitute_one_item($item): encoding indication doesn't match  '$encoding' ne '$close'\n" if $close && $encoding ne $close;

    my $value = $hash->{$guts};

    if ($guts =~ /^([\w_]+?)\((.+?)\)/)
    {
	my($f, $arglist) = ($1, $2);

	my @args = $arglist =~ /\G(?:\s* (\'(?:\\\'|.)*?\' | [\.\w]+ )  \s*  (?: , | $ ))/gx;

	for (@args)
	{
	    if (/^\'(.*)\'$/)
	    {
		$_ = $1;
		s/\\\'/\'/g;
	    }
	    else
	    {
		$_ = $hash->{$_};
	    }
	}

	$value = &$f(@args);
    }

    return $value if $encoding eq '<';
    return encode_field($value) if $encoding eq '&';
    return '"' . encode_field($value) . '"' if $encoding eq '"';
    return encode_url($value) if $encoding eq '%';
    return encode_field($value) if $entity_encode_by_default;

    return $value;
}

sub gen_select
{
    my($name, $sql) = @_;
    my $list = $dbh->selectall_arrayref($sql);
    my($width);
    for (@$list)
    {
	my $len = length($_->[0]);
	$width = $len if $len > $width;
    }
    my $html = "<select name=\"$name\">\n<option>- select -</option>\n";
    for (@$list)
    {
	my $value = $_->[0];
	$value = "$_->[0] - $_->[1]" if @$_ > 1;
	$html .= "<option value=$_->[0] @{[(exists $qwery{$name}{$_->[0]} || $query{$name} eq $_->[0])? 'selected': '']}>@{['&nbsp;' x ($width - length($_->[0]))]}$value</option>\n";
    }
    $html .= "</select>";
}

sub gen_options
{
    my($x, $html) = @_;

    my $selected = $x->{_selected};
    $selected->{$selected} = undef unless ref $selected;

    for my $key (sort {$x->{$a} cmp $x->{$b}} keys %$x)
    {
        next if $key eq '_selected';
        my $val = $x->{$key};
        my $attr = 'selected' if exists $selected->{$key};
        $html .= "<option $attr value=@{[encode_url($key)]}>$val</option>";
    }
    $html;
}


sub make_cookie_header
{
    my($name, $value) = @_;

    # Grab second-level domain.  Fails to match if HTTP_HOST is an IP address.
    my($domain) = $ENV{HTTP_HOST} =~ /([^\.]+\.[a-z]+)$/i;

    if ($domain)
    {
        "Set-Cookie: $name=$value; domain=$domain; path=/; expires=Thu, 15-Apr-2010 20:00:00 GMT";
    }
    else
    {
        "Set-Cookie: $name=$value; path=/; expires=Thu, 15-Apr-2010 20:00:00 GMT";
    }
}


sub get_cookie
{
    my($name, $value) = @_;

    for (split(/;\s*/, $ENV{HTTP_COOKIE}))
    {
	last if ($value) = /^$name=(.*)$/;
    }

    $value;
}


sub sign_on_off
{
    my($u, $secret1);

    for (split(/;\s*/, $ENV{HTTP_COOKIE}))
    {
	last if ($u) = /^u=(.*)$/;
    }
    if (exists $query{username})
    {
	$hash{username} = $query{username};
    }
    else
    {
	($hash{username}, $secret1) = split(/ /, $u, 2);
    }

    if ($query{action} eq 'signoff')
    {
	push @set_headers, set_cookie_header(u => $hash{username});
	finish('signon', \%hash);
	exit;
    }

    my($secret, $foo) = $dbh->selectrow_array("select sha1('Allan hates it! / $hash{username}'),16");

    if ($secret1 ne $secret)	# if cookie is not valid
    {
	if (! exists $query{username})	# not in process of logging in
	{
	    finish('signon', \%hash);
	    exit;
	}
	elsif (! $query{username})	# not in process of logging in
	{
	    $hash{message} = 'Enter your email address';
	    finish('signon', \%hash);
	    exit;
	}
	else
	{
	    $hash{username} = $query{username};

	    my $sql = "select password from v2info.account where account = ?";
	    my @sql = ($query{username});
	    my($password) = $dbh->selectrow_array($sql, undef, @sql);

	    if ($password eq $query{password} and $query{password} eq "change!me") {	# default password?
		push @set_headers, set_cookie_header(u => "$query{username} $secret");
	    	$hash{message} = 'Your account currently has the default password.  You must select a new password in order to continue.';
		finish('changepw', \%hash);
		exit;
	    }

	    if (length($query{password}) < 4 || $query{password} ne $password) # passwords don't match
	    {
		$hash{message} = "Invalid password";
		finish('signon', \%hash);
		exit;
	    }

	    # successful sign on
	    $dbh->do("update v2info.account set lastlogin = now(), ip = ? where account=? ", undef, $ENV{REMOTE_ADDR}, $query{username});

	    push @set_headers, set_cookie_header(u => "$query{username} $secret");
	}
    }

    if ($hash{username} =~ /^(?:al|del|gary|jennifer|larry|timkay|tom)$/)
    {
	$debug = $query{debug};

	# allow name to be changed for debugging
	$hash{username} = $query{un} if $query{un};
    }

    $hash{greeting} = $hash{username};
}


sub set_cookie_header
{
    my($name, $value) = @_;

    # Grab second-level domain.  Fails to match if HTTP_HOST is an IP address.
    my($domain) = $ENV{HTTP_HOST} =~ /([^\.]+\.[a-z]+)$/i;

    my $expires = "Thu, 01-Jan-1970 00:00:01 GMT";
    $expires = "Thu, 31-Dec-2020 20:00:00 GMT" if $value;

    if ($domain)
    {
	"Set-Cookie: $name=$value; domain=$domain; path=/; expires=$expires";
    }
    else
    {
	"Set-Cookie: $name=$value; path=/; expires=$expires";
    }
}


sub set_cookie
{
    push @set_headers, set_cookie_header(@_);
}

*delete_cookie = *set_cookie;

1;
