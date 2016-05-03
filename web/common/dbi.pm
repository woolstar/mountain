

use DBI;


sub common::dbi::import
{
    my $package = shift;
    my %param = @_;

    my $db = $param{db} || $program;
	my $user = $param{user} || "root" ;

    # Don't RaiseError on a failed open, as the death can't be caught
    # by the main program at this point, and the user will see an
    # ugly error message.

    my $home = (getpwuid($<))[7];

    $dbh = DBI->connect("dbi:mysql:;host=127.0.0.1", $user, undef, {PrintError => 0, RaiseError => 0});
	
    if ($dbh)
    {
	$dbh->do("use $db");
	$dbh->{RaiseError} = 1;
    }
}


sub dbexec
{
    my($sql, @sql) = @_;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@sql);
    die "@{[$dbh->errstr]}\n" if $dbh->errstr;

    $sth ;
}

sub selectall_arrayhashref
{
    my($sql, @sql) = @_;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@sql);
    die "@{[$dbh->errstr]}\n" if $dbh->errstr;
    my(@result);
    while (my $href = $sth->fetchrow_hashref)
    {
	push @result, $href;
    }
    \@result;
}


sub optimize
{
    my($sql, @sql) = @_;
    my($sql2, @sql2);

    for (split(/(\(select(?:\(.*?\)|.)*?\))/, $sql))
    {
	my(@sql3);

	s/\s+/ /g;

	for (/\?/g)
	{
	    push @sql3, shift @sql;
	}

	if (/\((select .*)\)/)
	{
	    $sql2 .= "(" . join(',', @{$dbh->selectcol_arrayref($_, undef, @sql3)}) . ")";
	}
	else
	{
	    $sql2 .= $_;
	    push @sql2, @sql3;
	}
    }

    #print "@sql2  $sql2\n";
    return ($sql2, @sql2);
}


sub dumpsql
{
    return unless $sql || $query{sql};

    my $sql = shift;
    for my $s (@_)
    {
	$s =~ s/\'/''/g;
	$sql =~ s/\?/'$s'/;
    }
    print "$sql\n";
}


1;
