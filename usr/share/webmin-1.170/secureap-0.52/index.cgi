#!/usr/bin/perl
# index.cgi
# Display current iptables firewall configuration from save file

require './secureap-lib.pl';

mountrw();

&ReadParse();
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));

my $action	= $in{action};

if ($action eq "Apply")
{
	#	-- perform some basic validity check
	# if (length($in{"PSK_KEY"}) < 8 || length($in{"PSK_KEY"}) > 63 || length($in{"PSK_KEY"}) != 0)
	# {
	# 	print "Settings denied!<br>Invalid PSK key length";
	# }
	# else
	# {
		#	-- Manipulate smartap.conf
		if 	($in{activate80211i} eq "on") {set_80211i_permenant("1");}
		else	{set_80211i_permenant("0");};

		#	-- Manipulate hostapd.conf
		set_property("auth_server_addr", $in{"EAP_SERVER_IP"});
		set_property("auth_server_shared_secret", $in{"EAP_PASSPHRASE"});
		set_property("auth_server_port", $in{"EAP_PORT"});
		set_property("wpa_passphrase", $in{"PSK_KEY"});
		set_property("own_ip_addr", $in{"OWN_IP_ADDRESS"});
		if ($in{WPA_KEY_MGMT} eq "WPA-PSK") {
			set_property("wpa_key_mgmt", "WPA-PSK");
		}
		elsif ($in{WPA_KEY_MGMT} eq "WPA-EAP") {
			set_property("wpa_key_mgmt", "WPA-EAP");
		}
		else {
			set_property("wpa_key_mgmt", "WPA-EAP WPA-PSK");
		}
	# }

	# 	-- Restart hostapd
	if (get_80211i_permenant("WPA2_ACTIVATE") eq "1")
	{
		stop_hostapd();
		start_hostapd();
	}
	else
	{
		stop_hostapd();
	}
}

my $checked			= ""; if (get_80211i_permenant("WPA2_ACTIVATE") eq "1") { $checked = "checked"; }
my $EAP_SERVER_IP	= get_property("auth_server_addr");
my $EAP_PASSPHRASE	= get_property("auth_server_shared_secret");
my $EAP_PORT		= get_property("auth_server_port");
my $PSK_KEY			= get_property("wpa_passphrase");
my $WPA_KEY_MGMT	= get_property("wpa_key_mgmt");
my $OWN_IP_ADDRESS	= get_property("own_ip_addr");

print "	<form action=index.cgi method=post>
	<table width=90% align=center>
	<tr><th colspan=2>Configuration</th></tr>
	<tr><td width=40%>Activate 802.11i on restart</td><td><input type=checkbox name=activate80211i $checked></td></tr>
	<tr><td>WPA Key Management</td>
		<td>
		<select name=WPA_KEY_MGMT>
			<option value=WPA-PSK> Pre-Shared Key (PSK)</option>
			<option value=WPA-EAP selected> 802.1x EAP</option>
			<option value=BOTH> Both PSK and EAP</option>
		</select> <br>Current: <font color=red><b>$WPA_KEY_MGMT</b></font>
		</td> 
	</tr>
	<tr><td>Own IP Address</td><td><input name=OWN_IP_ADDRESS value=$OWN_IP_ADDRESS></td></tr>
	<tr><th>802.1x (EAP) Settings</th><th>Value</th></tr>
	<tr><td>802.1x EAP Server</td><td><input name=EAP_SERVER_IP value=$EAP_SERVER_IP></td></tr>
	<tr><td>802.1x PassPhrase</td><td><input name=EAP_PASSPHRASE value=$EAP_PASSPHRASE></td></tr>
	<tr><td>802.1x Port</td><td><input name=EAP_PORT value=$EAP_PORT size=4></td></tr>
	<tr><th width=50%>Pre-Shared Key (PSK) Settings</th><th>Value</th></tr>
	<tr><td>Pre-Shared Key for WPA-PSK</td><td><input name=PSK_KEY value=$PSK_KEY>
						<br><font color=orange>
						Please provide key length between 8 and 63 ASCII characters.<br>
						Other key lengths will not work!</font>
						</td></tr>
	<tr><td></td><td><input type=submit name=action value='Apply'>
			<br><span class=sys_msg>This will restart the AP. You may have to reauthenticate clients.</span></td></tr>
	</td></tr>
	</form>
	</table>";

&ui_print_footer("/", $text{'index'});
