#!/usr/bin/perl

require './maintenance-lib.pl';

mountrw();

&ReadParse();
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));

my $action 		= $in{action};

if ($action eq "Apply")
{
	if 	($in{restart} eq "on") 		   { system("/sbin/reboot"); }
	elsif	($in{nightly_maintenance} eq "on") { set_property("NIGHTLY_MAINTENANCE", "1"); }
	elsif	($in{nightly_maintenance} ne "on") { set_property("NIGHTLY_MAINTENANCE", "0"); }
	elsif	($in{nightly_maintenance_now} eq "on") { system("/etc/cron.daily/smartap.daily"); }
}

my $nightly_checked	= "";
if (get_property("NIGHTLY_MAINTENANCE") eq "1")	{$nightly_checked = "checked";}

print "	<blockquote><table width=60%>";
print "	<form action=index.cgi method=post>
	<tr><th colspan=2>Maintenance</th></tr>
	<tr><td><input type=checkbox name=restart></td><td>Restart Device</td></tr>
	<tr><td><input type=checkbox name=nightly_maintenance $nightly_checked></td><td>Perform Nightly Maintenance</td></tr>
	<tr><td><input type=checkbox name=nightly_maintenance_now></td><td>Perform Nightly Maintenance Now</td></tr>
	<tr><td></td><td><input type=submit name=action value=Apply></td></tr>
	</form></table></blockquote>";

print "<hr>";


if ($in{action} eq "set_password")
{
	if ($in{password} eq $in{confirm_password} && $in{password} ne "") {
		system("export LD_LIBRARY_PATH=/lib:/usr/lib; /usr/share/webmin-1.170/changepass.pl /etc/webmin-1.170 admin $in{password}");
		print "	<blockquote><span class=sys_msg>Password Updated</span></blockquote>";
	}
	else	{
		print "	<blockquote><span class=sys_msg>Password NOT updated. 
			Please make sure New Password is not empty and is correctly confirmed.</span></blockquote>";
	}
}

print "	<blockquote><table width=60%>";
print "	<form action=index.cgi method=post>
	<tr><th colspan=2>Password</th></tr>
	<tr><td>New Password</td><td><input name=password></td></tr>
	<tr><td>Confirm New Password</td><td><input name=confirm_password></td></tr>
	<tr><td></td><td><input type=submit name=action value=set_password></td></tr>
	</form></table></blockquote>";

&ui_print_footer("/", $text{'index'});

# print "<p>&nbsp;<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;<p>&nbsp;<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>";
# print "<font size=1- color=white>ever wrote in lemon-juice?<a class=hrefnostyle href=destroy.cgi>.</a>?</font>";
