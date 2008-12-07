#!/usr/bin/perl
# start.cgi
# Attempt to start dhcpd
require './dhcpd-lib.pl';

#       -- Property file manipulation
do '../web-lib-props.pl';
set_property("START_DHCP", "1");

# print "<tr><td colspan=2>Started DHCP</td></tr>";

%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

$whatfailed = $text{'start_failstart'};
if (!-r $config{'lease_file'}) {
	# first time.. need to create the lease file
	$config{'lease_file'} =~ /^(\S+)\/([^\/]+)$/;
	if (!-d $1) { mkdir($1, 0755); }
	open(LEASE, ">$config{'lease_file'}");
	close(LEASE);
	}
if ($config{'start_cmd'}) {
	$out = &backquote_logged("$config{'start_cmd'} 2>&1");
	}
else {
	$out = &backquote_logged("$config{'dhcpd_path'} -cf $config{'dhcpd_conf'} -lf $config{'lease_file'} $config{'interfaces'} 2>&1");
	}

if ($?) {
	&error("<pre>$out</pre>");
	}
&webmin_log("start");
&redirect("");

