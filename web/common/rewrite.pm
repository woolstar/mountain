
sub absolute
{
    my($base, $uri) = @_;
    return $uri if $uri =~ /^https?:\/\//i;
    return $uri if $uri =~ /^javascript:/i;
    return join('', $base =~ /^((?:https?:\/\/)?[^\Q$1\E]*)\Q$1\E?/, $uri) if $uri =~ /^([\/\#\?])/;
    $base .= "/" if $base =~ /^https?:\/\/[^\/]*$/;
    return join('', $base =~ /^(.*\/)/, $uri);
}

sub	xmlpp
{
	my $indent= "  " ;
    my(@path, $defer, @defer);
	my $x= "" ;

    for ( map { /<.*?>|[^<]*/sg } @_ )
	{
		if (/^<\/(\w+)/ || /^<(!\[endif)/)		# </... or <!--[endif]
		{
			my($tag) = ($1);
			$tag = $path[$#path] if $tag eq "![endif";
			push @path, @defer;
			while (@path) { my $pop = pop @path ; last if $pop eq $tag }
			$x .= "@{[$indent x @path]}@{[$defer =~ /^\s*(.*?)\s*$/s]}$_\n" if $defer || $_;
			$defer = "";
			@defer = ();
		}

		elsif (/[\/\?]\s*\>$/)				# .../> or ...?>
		{
			$x .= "@{[$indent x @path]}@{[$defer =~ /^\s*(.*?)\s*$/s]}\n" if $defer;
			push @path, @defer;
			$x .= "@{[$indent x @path]}@{[/^\s*(.*?)\s*$/s]}\n" if $_;
			$defer = "";
			@defer = ();
		}

		elsif (/^(?:[^<]|<!(?:[^-]|--[^\[]))/)		# (not <) or (</not -) or (<!--/not [)
		{
			if (!/^\s*$/) {
				if ($defer) { $defer .= $_; }
					else { $x .= "@{[$indent x @path]}@{[/^\s*(.*?)\s*$/s]}\n" }
			}
		}

		else						# <...
		{
			$x .= "@{[$indent x @path]}@{[$defer =~ /^\s*(.*?)\s*$/s]}\n" if $defer;
			push @path, @defer;
			$defer = $_;
			@defer = /^<([^<>\s]+)/;
		}

	}

	$x
}

sub		json_esc
{
	my ( $txt)= @_ ;

	$txt =~ s/\\/\\\\/g ;
	$txt =~ s/"/\\"/g ;
	$txt =~ s/\n/\\n/g ;

	$txt
}

sub		json_quote
{
	my ( $txt)= @_ ;

	return $txt if $txt =~ /^([1-9]\d*)$/ ;
	'"' . json_esc($txt) . '"'
}

sub		json_encode
{
	my ( $rec_ )= @_ ;
	my $t= ref $rec_ ;

	return json_esc( $$rec_ ) if 'SCALAR' eq $t ;
	return "[ ". join(', ' . "\n",
		map { (ref $_ ) ? json_encode($_) : json_quote( $_) } @$rec_ ) . " ]"
		if 'ARRAY' eq $t ;

	return "x$t\x" unless 'HASH' eq $t ;

	my $str= '' ;
	foreach my $k ( sort keys %$rec_ ) {
		my $v= $rec_->{$k} ;
		my $val= ( ref $v ) ? json_encode($v) : json_quote( $v) ;
		$str .= "\t\"$k\": $val,\n"
	}

	"{\n" . $str . "}\n"
}

1;

