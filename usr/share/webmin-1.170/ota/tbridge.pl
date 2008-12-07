#!/usr/bin/perl

# Copyright Wapsol GmbH, Feldbergstrasse 62, D-70569 Stuttgart. All rights reserved
#
# Script for configuring a WDS based IWN NetNode v.0.80 

use CGI;
use Config::Properties;

my $query       	= new CGI;                                      # Object for parsing POST request values
my %cgi_par     	= $query->Vars();                               # stores request values

my $template_file	= "/usr/local/www/iwn/template.html";
my $tbridge_html	= "/usr/local/www/iwn/.html/tbridge.html";

my $config_file		= "/etc/wds.conf";

my $action		= $cgi_par{action};
my $clientip		= $query->remote_host();

my $CLIENT_IP_RANGE	= "10.0.0";

print $query->header();

if ($action eq "set_self_node")
{
	set_property("SELF_IP", $cgi_par{selfip});
	set_property("SELF_NETMASK", $cgi_par{selfnetmask});
	set_property("SELF_BROADCAST", $cgi_par{selfbroadcast});
	set_property("SELF_DEFAULT_GW", $cgi_par{selfdefaultgw});
}
elsif ($action eq "set_peer")
{
	$peer_max	= get_peer_max();

	if ($cgi_par{newpeermac} ne "")
	{
		set_property("PEERMAC_$peer_max", $cgi_par{newpeermac});
		set_property("PEERIP_$peer_max", $cgi_par{newpeerip});
	}
}
elsif ($action eq "delete_peer")
{
	delete_peer($cgi_par{peernodeindex});
}

print_properties();

return 1;
