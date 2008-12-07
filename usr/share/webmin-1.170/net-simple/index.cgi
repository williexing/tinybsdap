#!/usr/bin/perl
# index.cgi
# Display current iptables firewall configuration from save file

require './net-simple-lib.pl';
mountrw();

&ReadParse();
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));

my $action		= $in{action};

if ($action eq "set_ethernet")
{
	my $eth0ip			= $in{eth0ip};
	my $eth0defgtwy		= $in{eth0defgtwy};
	my $eth0netmask		= $in{eth0netmask};
	my $eth0broadcast	= $in{eth0broadcast};

	# print "$eth0ip, $eth0defgtwy, $eth0netmask, $eth0broadcast"; return;

	set_property("DEFAULT_WIRELESS_IPADDR", $eth0ip);
	set_property("DEFAULT_WIRELESS_GATEWAY", $eth0defgtwy);
	set_property("DEFAULT_WIRELESS_NETMASK", $eth0netmask);
	set_property("DEFAULT_WIRELESS_BROADCAST", $eth0broadcast);

	print "<span class=sys_msg>Ethernet IP settings modified.</span>";
}
#elsif ($action eq "set_wireless")
#{
#	my $wlan0ip		= $in{wlan0ip};
#	my $wlan0defgtwy	= $in{wlan0defgtwy};
#	my $wlan0netmask	= $in{wlan0netmask};
#	my $wlan0broadcast	= $in{wlan0broadcast};
#
#	# print "$wlan0ip, $wlan0defgtwy, $wlan0netmask, $wlan0broadcast"; return
#
#	set_property("wlan0_ip", $wlan0ip);
#	set_property("wlan0_defgtwy", $wlan0defgtwy);
#	set_property("wlan0_netmask", $wlan0netmask);
#	set_property("wlan0_broadcast", $wlan0broadcast);
#
#	print "<span class=sys_msg>Wireless IP settings modified.</span>";
#}
#elsif ($action eq "set_default_gateway")
#{
#	# print "value = $in{defgtwy}";
#	set_property("eth0_defgtwy", $in{defgtwy});
#	system("/sbin/route add default gw $in{defgtwy}");
#}
elsif ($action eq "set_DNS")
{
	open(TFH,">/etc/swapdns.conf") || die " Unable to open swapdns.conf";;
	print TFH "nameserver " . $in{dns_1} . "\n";
	print TFH "nameserver " . $in{dns_2};
#	print TFH $in{dns_1};
#	print TFH "\n";
	open(FH,">/etc/resolv.conf") or die " Unable to open resolve.conf";
	while(my $ch = <FH>)
	{  
		print TFH $ch;
	}
	close(TFH);
	close(FH);
	system("export LD_LIBRARY_PATH=/lib:/usr/lib; cp /etc/swapdns.conf /etc/resolv.conf");
}


elsif ($action eq "set_DNS_option")
{
	#print "<span class=sys_msg>inside apply.</span>";
	if($in{dns_status} eq "true")
	{
		$dns=1;
		set_property("DNS_STATUS",$dns);
		#print "<span class=sys_msg>Dns settings modified.</span>";
	}
	elsif ($in{dns_status} eq "false") 
	{
		$dns=0;
		set_property("DNS_STATUS",$dns);
		# print "<span class=sys_msg>$dns.</span>";
	}
	print "<span class=sys_msg>Dns setting is updated.</span>";	
}

#	-- Present settings on the mask
#my $ETH0_IPADDR		= get_property("eth0_ip");
#my $ETH0_DEFGTWY	= get_property("eth0_defgtwy");
#my $ETH0_NETMASK	= get_property("eth0_netmask");
#my $ETH0_BROADCAST	= get_property("eth0_broadcast");
#
#my $WLAN0_IPADDR	= get_property("wlan0_ip");
#my $WLAN0_DEFGTWY	= get_property("wlan0_defgtwy");
#my $WLAN0_NETMASK	= get_property("wlan0_netmask");
#my $WLAN0_BROADCAST	= get_property("wlan0_broadcast");
#

my %config_hash	= getConfig("smartap.conf");

#print "<pre>";
#while ( my ($key, $value) = each(%config_hash) ) {
#    print "$key => $value\n";
#}
#print "</pre>";

print "	<form action=index.cgi method=post>";
print "	<table width=80% align=center>
	<tr><th colspan=2>Ethernet IP Settings</th></tr>
	<tr><td colspan=2>This configuration is effectively the main device IP configuration.</td></tr>
	<tr><td>IP Address</td><td><input name=eth0ip value=$config_hash{DEFAULT_WIRELESS_IPADDR}></td></tr>
	<tr><td>Network Mask</td><td><input name=eth0netmask value=$config_hash{DEFAULT_WIRELESS_NETMASK}></td></tr>
	<tr><td>Default Gateway</td><td><input name=eth0defgtwy value=$config_hash{DEFAULT_WIRELESS_GATEWAY}></td></tr>
	<tr><td>Broadcast</td><td><input name=eth0broadcast value=$config_hash{DEFAULT_WIRELESS_BROADCAST}></td></tr>
	<tr><td></td><td><input type=submit name=action value=set_ethernet></td></tr>
	</table>";
print "</form>";

print "<hr><p>";

#print "	<form action=index.cgi method=post>";
#print "	<table width=80% align=center>
#	<tr><th colspan=2>Wireless Interface IP Settings</th></tr>
#	<tr><td colspan=2>Please set this data for <u>Router</u> mode, for creating a separate subnet for WLAN network.</td></tr>
#	<tr><td>IP Address</td><td><input name=wlan0ip value=$WLAN0_IPADDR></td></tr>
#	<tr><td>Network Mask</td><td><input name=wlan0netmask value=$WLAN0_NETMASK></td></tr>
#	<tr><td>Default Gateway</td><td><input name=wlan0defgtwy value=$WLAN0_DEFGTWY></td></tr>
#	<tr><td>Broadcast</td><td><input name=wlan0broadcast value=$WLAN0_BROADCAST></td></tr>
#	<tr><td></td><td><input type=submit name=action value=set_wireless></td></tr>
#	</table>";
#print "</form>";
#print "<hr><p>";

#print "	<form action=index.cgi method=post>";
#print "	<table width=80% align=center>
#	<tr><th colspan=2>Default Gateway</th></tr>
#<tr><td colspan=2>Please provide default gateway for this device.</td></tr>
#	<tr><td>Default Gateway</td><td><input name=defgtwy value=$ETH0_DEFGTWY></td></tr>
#	<tr><td></td><td><input type=submit name=action value=set_default_gateway></td></tr>
#	</table>";
#print "</form>";

#my $status              = get_property("DNS_STATUS");
#my $dis_t_status        = $status eq "1" ? "checked" :"";
#my $dis_f_status        = $status eq "0" ? "checked" :""; 

my $ETH0_DEFDNS         = get_prim_dns();

my $dns_form_input, $ary_count;
foreach (get_dns_servers())
{
	$ary_count++;
	$dns_form_input .= "<tr><td width=200>$ary_count.</td><td><input name=dns_$ary_count value=$_ id=dns_$count></td></tr>";
}

print " <form action=index.cgi method=post>";
print " <table width=80% align=center>
        <tr><th colspan=2>Default DNS</th></tr>
		<tr><td colspan=2>Please list Primary and Secondary DNS servers below.</td></tr>
        <!--tr><td>Default DNServer</td><td><input name=defdns value=$ETH0_DEFDNS></td></tr-->
		$dns_form_input;
        <tr><td></td><td><input type=submit name=action value=set_DNS></td></tr>
        </table>";
print "</form>";

#print " <form action=index.cgi method=post>
#        <table width=80% align=center>
#        <tr><th colspan=2>Set DNS Host Lookup</th></tr>
#        <tr><td><input type=radio name=dns_status value=true $dis_t_status>enable</td>
#        <td><input type=radio name=dns_status value=false $dis_f_status>disable</td></tr>
#        <tr><td></td><td><input type=submit name=action value=set_DNS_option align=center></td></tr>
#        </table> </form>";


&ui_print_footer("/", $text{'index'});
