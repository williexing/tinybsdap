#!/usr/bin/perl

use Config::Properties;

require './wireless-lib.pl';

&ReadParse();
&header($text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));
print "<hr>\n";

mountrw();

my $action		= $in{action};
my $essid		= $in{essid};
my $channel		= $in{channel};
my $txpower		= $in{txpower};
my $bcast_ssid	= $in{bcast_ssid};
my $wepkey		= $in{wepkey};
my $mediaopt	= $in{mediaopt};

#print "action = $action | essid = $essid | channel = $channel | txpower = $txpower | brodcast = $bcast_ssid
#		wepkey = $wepkey | mode = $mode"; exit;

   if ($action eq "Submit")
   {
	#	-- Perform some checks on submited data, 
	#	   before making it effective on system

	# my $keylength	 = length($wepkey);
	# print "key length = $keylength <p>";

	# if ($keylength != 10 || $keylength != 26 || $keylength != 0)
	# {
	# 	print "<span class=sys_msg>Settings denied! <br>WEP Key of invalid length. 
	#		Please use key length of 10 or 26 characters, or leave empty.</span>";
	# }
   	# else
   	# {
		set_property('DEFAULT_WIRELESS_SSID', $essid);
		set_hostapd_property('ssid', $essid);
		set_property('DEFAULT_WIRELESS_CHANNEL', $channel);
		set_property('DEFAULT_WIRELESS_TXPOWER', $txpower);

		set_property('DEFAULT_WIRELESS_WEPKEY', $wepkey);
		set_property('DEFAULT_WIRELESS_MEDIAOPT', $mediaopt);

#		st_set_bcast_ssid($bcast_ssid);

#		st_run_iwconfig();
		print "<span class=sys_msg>802.11 parameters updated successfully!</span>";
   	# }
}

my $current_essid 	= st_get_param('DEFAULT_WIRELESS_SSID');
my $current_wepkey	= st_get_param('DEFAULT_WIRELESS_WEPKEY');

#my $iwconfig_out 	= st_get_iwconfig();
my $ifconfig_out 	= st_get_ifconfig();

print "<table><form action=index.cgi method=post>";
print "<tr><td valign=top colspan=2><span class=sec_header>Basic 802.11 Settings</span></td>";

my $mediaopt_hostap, $mediaopt_adhoc, $media_client;
   $mediaopt_master	= "selected" if (st_get_param('DEFAULT_WIRELESS_MEDIAOPT') eq 'hostap');
   $mediaopt_adhoc	= "selected" if (st_get_param('DEFAULT_WIRELESS_MEDIAOPT') eq 'adhoc');
   $mediaopt_client	= "selected" if (st_get_param('DEFAULT_WIRELESS_MEDIAOPT') eq 'client');

print "<tr><td>Wireless Mode</td><td>
			<select name=mediaopt>
			<option value=hostap $mediaopt_hostap>Access Point</option>
			<option value=adhoc $mediaopt_adhoc>Adhoc</option>
			<option value=client $mediaopt_client>Client</option>
			</select></td></tr>";

print "<tr><td width=25%>ESSID</td>
	<td><input name=essid value=$current_essid></td>";

$power_level = st_get_param('DEFAULT_WIRELESS_TXPOWER');
$select_99	 = "selected" if ($power_level eq '99');
$select_75	 = "selected" if ($power_level eq '75');
$select_50	 = "selected" if ($power_level eq '50');
$select_25	 = "selected" if ($power_level eq '25');

print "<tr><td>TX-Power</td>
	<td><select name=txpower>
		<option value=99 $select_100>100 %</option>
		<option value=75 $select_75>75 %</option>
		<option value=50 $select_50>50 %</option>
		<option value=25 $select_25>25 %</option>
	</td>";

my $channel	= st_get_param('DEFAULT_WIRELESS_CHANNEL');

print "<tr>
	<td>Channel</td>
	<td><select name=channel>
		<option value=1>1</option>
		<option value=3>3</option>
		<option value=5>5</option>
		<option value=7>7</option>
		<option value=9>9</option>
		<option value=11>11</option>
		</select>
		Current: <span class=sys_msg>$channel</span>
	</td>";

print "<tr><td valign=top colspan=2><span class=sec_header>Minimal Security</span></td>";
# print "<tr><td>Use WEP Encryption</td><td><input type=checkbox name=wepuse value=0 checked></td></tr>";
print "	<tr><td valign=top>WEP Key</td>
	<td><input type=text name=wepkey value=$current_wepkey>
		<br><font color=orange size=1->Please use Hexadecimal values [A-F,0-9]
		<br>Enter 10 characters for 40 bit encryption, 26 characters for 104 bit encryption
		<br>Other values will not work!
                <br>Leave empty if WEP is to be deactivated.
		</font></td></tr>";

print "<tr><td>Broadcast SSID</td>
	   <td><select name=bcast_ssid>
		<option value=0>0. Broadcast SSID</option>
		<option value=1>1. Hide SSID in Beacon Frames</option>
		<option value=2>2. Ignore Clients Configured with ANY</option>
		<option value=3 select>3. Hide SSID in Beacons &amp; Ignore ANY</option>
		</select></td>";

print "<tr><td valign=top>
		<input type=submit name=action value=Submit></td>
	   <td><pre>$ifconfig_out</pre></td>";
print "</form></table>";

print "<hr>\n";

&footer("/", $text{'index'});
