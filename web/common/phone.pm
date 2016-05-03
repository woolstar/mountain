

if ($ENV{HTTP_USER_AGENT} =~ /blackberry/i)
{
    $phone_os = "blackberry";
    ($phone_os_edition) = $ENV{HTTP_USER_AGENT} =~ /BlackBerry.*?\/(\d+\.\d+\.\d+)/i;
    $phone_os_version = $phone_os_edition;
}
elsif ($ENV{HTTP_UA_OS} =~ /^windows ce/i || $ENV{HTTP_USER_AGENT} =~ /windows ce/i)
{
    # UA_OS comes from PIE, but USER_AGENT comes from Opera
    $phone_os = "winmo";
}
elsif ($ENV{HTTP_USER_AGENT} =~ /blazer/i)
{
    $phone_os = "palm";
}
elsif (0
       || $ENV{HTTP_USER_AGENT} =~ /SymbianOS\/(\d+\.\d+)/i && $1 >= 9.1
       || $ENV{HTTP_USER_AGENT} =~ /Series60\/(\d+\.\d+)/i && $1 >= 3.0
       )
{
    $phone_os = "symbian";
    ($phone_os_version) = $ENV{HTTP_USER_AGENT} =~ /SymbianOS\/(\d+\.\d+)/i;
    ($phone_os_edition) = $ENV{HTTP_USER_AGENT} =~ /Series60\/(\d+\.\d+)/i;
}
elsif ($ENV{HTTP_USER_AGENT} =~ /Android/i)
{
    $phone_os = "android";
}
elsif ($ENV{HTTP_USER_AGENT} =~ /CLDC|MIDP|MMP\/2/i)
{
    $phone_os = "j2me";
}
elsif ($ENV{HTTP_USER_AGENT} =~ /iPhone/)
{
    $phone_os = "iphone";
}
elsif ($ENV{HTTP_USER_AGENT} =~ /Tablet browser/)
{
    $phone_os = "tablet";
}


1;
