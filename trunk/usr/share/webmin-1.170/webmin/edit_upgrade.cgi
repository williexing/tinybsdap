#!/usr/local/bin/perl
# edit_upgrade.cgi
# Display a form for upgrading all of webmin from a tarfile

require './webmin-lib.pl';
require './gnupg-lib.pl';
&ui_print_header(undef, $text{'upgrade_title'}, "");

# what kind of install was this?
if (open(MODE, "$root_directory/install-type")) {
	chop($mode = <MODE>);
	close(MODE);
	}
else {
	if ($root_directory eq "/usr/libexec/webmin") {
		$mode = "rpm";
		}
	elsif ($root_directory eq "/opt/webmin") {
		$mode = "solaris-pkg";
		}
	else {
		$mode = undef;
		}
	}

# was the install to a target directory?
if (open(DIR, "$config_directory/install-dir")) {
	chop($dir = <DIR>);
	close(DIR);
	}

if ($mode eq "solaris-pkg") {
	print "<p>$text{'upgrade_esolaris'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Display upgrade form
print "<table width=100%><tr><td valign=top>\n";
print $text{"upgrade_desc$mode"},"</td><td valign=top>";

print "<form action=upgrade.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=mode value='$mode'>\n";
print "<input type=hidden name=dir value='$dir'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'upgrade_title'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";
print "<input type=radio name=source value=0> $text{'upgrade_local'}\n";
print "<input name=file size=40>\n";
print &file_chooser_button("file", 0),"<br>\n";
print "<input type=radio name=source value=1> $text{'upgrade_uploaded'}\n";
print "<input name=upload type=file size=30><br>\n";
print "<input type=radio name=source value=5> $text{'upgrade_url'}\n";
print "<input name=url size=40><br>\n";
if ($mode eq 'caldera') {
	print "<input type=radio name=source value=3 checked> $text{'upgrade_cup'}\n";
	}
elsif ($mode eq "gentoo") {
	print "<input type=radio name=source value=4 checked> $text{'upgrade_emerge'}\n";
	}
else {
	print "<input type=radio name=source value=2 checked> $text{'upgrade_ftp'}\n";
	}
print "<p>\n";
if (!$mode && !$dir) {
	print "<input type=checkbox name=delete value=1> ",
		"$text{'upgrade_delete'}<br>\n";
	}
if ((!$mode || $mode eq "rpm") && &foreign_check("proc")) {
	($ec, $emsg) = &gnupg_setup();
	printf "<input type=checkbox name=sig value=1 %s> %s<br>\n",
		$ec ? "" : "checked", $text{'upgrade_sig'};
	}
if (!$mode) {
	printf "<input type=checkbox name=only value=1 %s> %s<br>\n",
		-r "$root_directory/minimal-install" ? "checked" : "",
		$text{'upgrade_only'};
	}
printf "<input type=checkbox name=force value=1> %s<br>\n",
	$text{'upgrade_force'};
print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'upgrade_ok'}\">\n";
print "</form></td></tr>\n";

# Display new module grants form
print "<tr> <td valign=top>$text{'newmod_desc'}</td> <td>\n";
print "<form action=save_newmod.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td valign=top><b>$text{'newmod_header'}</b></td> </tr>\n";
print "<tr> <td $cb>\n";

$newmod = &get_newmodule_users();
printf "<input type=radio name=newmod_def value=1 %s> %s<br>\n",
	$newmod ? "" : "checked", $text{'newmod_def'};
printf "<input type=radio name=newmod_def value=0 %s> %s\n",
	$newmod ? "checked" : "", $text{'newmod_users'};
printf "<input name=newmod size=30 value='%s'><br>\n",
	join(" ", @$newmod);

print "</td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";
print "</td></tr></table>\n";

print "<hr>\n";

# Display module update form
print "<table width=100%>\n";
print "<tr> <td valign=top>$text{'update_desc1'}</td>\n";
print "<td><form action=update.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'update_header1'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";

printf "<input type=radio name=source value=0 %s> %s<br>\n",
	$config{'upsource'} ? "" : "checked", $text{'update_webmin'};
printf "<input type=radio name=source value=1 %s> %s\n",
	$config{'upsource'} ? "checked" : "", $text{'update_other'};
printf "<input name=other size=30 value='%s'><br>\n",
	$config{'upsource'};

printf "<input type=checkbox name=show value=1 %s> %s<br>\n",
	$config{'upshow'} ? "checked" : "", $text{'update_show'};
printf "<input type=checkbox name=missing value=1 %s> %s<br>\n",
	$config{'upmissing'} ? "checked" : "", $text{'update_missing'};
printf "<input type=checkbox name=third value=1 %s> %s<br>\n",
	$config{'upthird'} ? "checked" : "", $text{'update_third'};
print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'update_ok'}\">\n";
print "</form></td></tr></table>\n";

print "<hr>\n";

# Display scheduled update form
print "<table width=100%>\n";
print "<tr> <td valign=top>$text{'update_desc2'}</td>\n";
print "<td><form action=update_sched.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'update_header2'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";
printf "<input type=checkbox name=enabled value=1 %s> %s<p>\n",
	$config{'update'} ? 'checked' : '', $text{'update_enabled'};
	
printf "<input type=radio name=source value=0 %s> %s<br>\n",
	$config{'upsource'} ? "" : "checked", $text{'update_webmin'};
printf "<input type=radio name=source value=1 %s> %s\n",
	$config{'upsource'} ? "checked" : "", $text{'update_other'};
printf "<input name=other size=30 value='%s'><br>\n",
	$config{'upsource'};

$upmins = sprintf "%2.2d", $config{'upmins'};
print &text('update_sched2',
	    "<input name=hour size=2 value='$config{'uphour'}'>",
	    "<input name=mins size=2 value='$upmins'>",
	    "<input name=days size=3 value='$config{'updays'}'>"),"<br>\n";

printf "<input type=checkbox name=show value=1 %s> %s<br>\n",
      $config{'upshow'} ? 'checked' : '', $text{'update_show'};
printf "<input type=checkbox name=missing value=1 %s> %s<br>\n",
      $config{'upmissing'} ? 'checked' : '', $text{'update_missing'};
printf "<input type=checkbox name=third value=1 %s> %s<br>\n",
	$config{'upthird'} ? "checked" : "", $text{'update_third'};
printf "<input type=checkbox name=quiet value=1 %s> %s<br>\n",
      $config{'upquiet'} ? 'checked' : '', $text{'update_quiet'};
printf "%s <input name=email size=30 value='%s'><br>\n",
	$text{'update_email'}, $config{'upemail'};

print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'update_apply'}\">\n";
print "</form></td></tr></table>\n";

&ui_print_footer("", $text{'index_return'});

