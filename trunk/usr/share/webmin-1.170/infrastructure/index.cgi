#!/usr/bin/perl
# index.cgi
# Display current iptables firewall configuration from save file

require './infrastructure-lib.pl';

mountrw();

&ReadParse();
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));

my $action	= $in{action};

if ($action eq "set_mode")
{
	if 	($in{mode} eq "Router") 
	{ 
		set_property("NETWORK_MODE", 0); 
		set_hostapd_property("iapp_interface", "eth0");
		
	}
	elsif	($in{mode} eq "Bridging") 
	{ 
		set_property("NETWORK_MODE", 1); 
		set_hostapd_property("iapp_interface", "br0");
		
	}
	elsif	($in{mode} eq "OTA") 	
	{ 
		set_property("NETWORK_MODE", 2); 
		set_hostapd_property("iapp_interface", "br0");
		
	}

	print "<p class=sys_msg>Network mode changed to <b>$in{mode}</b>. Device will now restart.</p>";
	system("/usr/local/sbin/fastreboot");
}

my $current_mode	= get_property("NETWORK_MODE");

print "<span class=sec_header>Current Mode:</span> ";
if 	($current_mode eq "2") {print "WifiMAX OTA";}
elsif 	($current_mode eq "1") {print "Bridging";}
elsif 	($current_mode eq "0") {print "Router";}
else	{print "Undetermined Network Mode"};

my $modes_available	= get_property("NETWORK_MODES_AVAILABLE");
my @modes	= split(/_/, $modes_available);

print "<p class=sec_header>Set Network Mode</p>";

print "<blockquote>";
print "<form method=post action=index.cgi>";
foreach $mode (@modes)	{
	print "<input type=radio name=mode value=$mode> $mode<p>";
}
print "<input type=submit name=action value=set_mode></form>";
print "</blockquote>";

&ui_print_footer("/", $text{'index'});
