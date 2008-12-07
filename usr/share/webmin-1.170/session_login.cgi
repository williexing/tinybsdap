#!/usr/bin/perl
# session_login.cgi
# Display the login form used in session login mode

$pragma_no_cache = 1;
#$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
require './web-lib.pl';
require './web-lib-props.pl';

&init_config();
&ReadParse();
if ($gconfig{'loginbanner'} && $ENV{'HTTP_COOKIE'} !~ /banner=1/ &&
    !$in{'logout'} && !$in{'failed'} && !$in{'timed_out'}) {
	# Show pre-login HTML page
	print "Set-Cookie: banner=1; path=/\r\n";

	&PrintHeader();
	$url = $in{'page'};
	open(BANNER, $gconfig{'loginbanner'});
	while(<BANNER>) {
		s/LOGINURL/$url/g;
		print;
		}
	close(BANNER);
	return;
	}
$sec = uc($ENV{'HTTPS'}) eq 'ON' ? "; secure" : "";
&get_miniserv_config(\%miniserv);
print "Set-Cookie: banner=0; path=/$sec\r\n" if ($gconfig{'loginbanner'});
print "Set-Cookie: $config{'sidname'}=x; path=/$sec\r\n" if ($in{'logout'});
print "Set-Cookie: testing=1; path=/$sec\r\n";
&header(undef, undef, undef, undef, 1, 1, undef, undef,
	"onLoad='document.forms[0].pass.value = \"\"; document.forms[0].user.focus()'");
# print "<hr>\n";

print "<font face=arial size=-1>";
print "<center>\n";
print "<br><img src=/images/newlogo.gif><br>";
print "<p style='font-size: 12pt; font-weight:bold; text-align: center'>";
if (defined($in{'failed'})) {
	print "$text{'session_failed'}<p>\n";
	}
elsif ($in{'logout'}) {
	print "$text{'session_logout'}<p>\n";
	}
elsif ($in{'timed_out'}) {
	print "",&text('session_timed_out', int($in{'timed_out'}/60)),"<p>\n";
	}
print "</p>";
print "$text{'session_prefix'}\n";
print "<form action=$gconfig{'webprefix'}/session_login.cgi method=post>\n";
print "<input type=hidden name=page value='".&html_escape($in{'page'})."'>\n";
print "<table border=0 width=600 class=main style='font-size: 9pt;'>\n";
print "<tr $tb> <td><b>$text{'session_header'}</b></td> </tr>\n";
print "<tr $cb> <td align=center><table style='font-size: 9pt;' cellpadding=3>\n";
if ($gconfig{'realname'}) {
	$host = &get_system_hostname();
	}
else {
	$host = $ENV{'HTTP_HOST'};
	$host =~ s/:\d+//g;
	$host = &html_escape($host);
	}
print "<tr> <td colspan=2 align=center>",
      &text($gconfig{'nohostname'} ? 'session_mesg2' :
	    $gconfig{'usermin'} ? 'session_mesg3' : 'session_mesg',
	    "<tt>$host</tt>"),"</td> </tr>\n";
print "<tr> <td><b>$text{'session_user'}</b></td>\n";
print "<td><input name=user size=20 value='".&html_escape($in{'failed'})."'></td> </tr>\n";
print "<tr> <td><b>$text{'session_pass'}</b></td>\n";
print "<td><input name=pass size=20 type=password></td> </tr>\n";
print "<tr> <td colspan=2 align=center><input type=submit value='$text{'session_login'}'>\n";
print "<input type=reset value='$text{'session_clear'}'><br>\n";
if (!$gconfig{'noremember'}) {
	print "<input type=checkbox name=save value=1> $text{'session_save'}\n";
	}
print "</td> </tr>\n";
print "</table></td></tr></table><p>\n";

#	-- Wapsol code for printing device information
print_device_info();
#	-- End Wapsol code

print "</form></center>\n";
print "$text{'session_postfix'}\n";

# Output frame-detection Javascript, if theme uses frames
if ($tconfig{'inframe'}) {
	print <<EOF;
<script>
if (window != window.top) {
	window.top.location = window.location;
	}
</script>
EOF
	}
&footer();

# print "</font>";


sub print_device_info
{
#	my $dns_status  = get_property("dns_status");
#	my $ipaddr	= get_property("eth0_ip");
#	my $essid	= get_property("wlan0_essid");
#        my $dns;
#	my $netmode	= "";
#	if 	(get_property("NETWORK_MODE") eq "0") { $netmode = "Router"; }
#	elsif	(get_property("NETWORK_MODE") eq "1") { $netmode = "Bridging"; }
#	elsif	(get_property("NETWORK_MODE") eq "2")
#                { $netmode = "OTA";}
#	else	{print "Undetermined"};
# 	          if (get_property("dns_status") eq "1")
# 	          {
# 	          	$dnsstatus=&dnscheck();
#		          if($dnsstatus eq 0)
#        	           	{
#        		      $dns = "DNS invlalid or unable to contact DNS "
#                   		}
#      		 	else 	
#      		 		{
#	             		 $dns=$dnsstatus;
#		      		}   	
#		      }
#	my $uptime	= &time();
#	my $wlan0_mac	= get_property("wlan0_mac");
#	my $eth0_mac	= get_property("eth0_mac");
	my $uptime = `/usr/bin/uptime`;
	my %config_hash	=	getConfig("smartap.conf");
	print "	<table border=0 width=70% align=center style='color: #FF6600; font-size: 10pt; font-weight=bold; vertical-align=top;'>
		<tr><td>IP Address</td>		<td>$config_hash{DEFAULT_WIRELESS_IPADDR}</td></tr>
		<tr><td>MAC Address</td>	<td>WLAN - $config_hash{DEFAULT_WIRELESS_MAC}<br>Bridge - $config_hash{DEFAULT_LAN_MAC}</td></tr>
		<tr><td>Uptime</td>		<td>$uptime</td></tr>
		<tr><td>ESSID</td>		<td>$config_hash{DEFAULT_WIRELESS_SSID}</td></tr>
		<tr><td>Network Mode</td>	<td>802.11a Access Point 54 Mbps</td></tr>
		<tr><td>$dns</td></tr></table>"
	
}

#sub dnscheck
#{
#	system("/usr/bin/dnscache");
#		
# use Socket;
# open(FH,"temp") or die "Can't open the DNS file";
# while(my $ip = <FH>)
# {
#     $acpthost = gethostbyaddr(inet_aton($ip), AF_INET);
#      if( $acpthost ne "")
#     {
#       return "$acpthost";
#      }
# }
# return "0";
#}
      
#sub time
#{
#system ("/usr/bin/uptime.sh");
#open (FH,"/usr/bin/timefile") or die "Can't open the time file";
#while(my $time = <FH>)
#{
#return "$time";
#}
#}
