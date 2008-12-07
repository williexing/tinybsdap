#!/usr/local/bin/perl
# edit_log.cgi
# Logging config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'log_title'}, "");
&foreign_require("acl", "acl-lib.pl");
&get_miniserv_config(\%miniserv);

print &text('log_desc', "<tt>$miniserv{'logfile'}</tt>"),"<p>\n";
print &text('log_desc2', "<tt>$webmin_logfile</tt>"),"<p>\n";

print "<form action=change_log.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'log_header'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";
printf "<input type=radio name=log value=0 %s> $text{'log_disable'}<p>\n",
	!$miniserv{'log'} ? "checked" : "";
printf "<input type=radio name=log value=1 %s> $text{'log_enable'}<br>\n",
	$miniserv{'log'} ? "checked" : "";
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=loghost value=1 %s>\n",
	$miniserv{'loghost'} ? "checked" : "";
print "$text{'log_resolv'}<br>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=logclf value=1 %s>\n",
	$miniserv{'logclf'} ? "checked" : "";
print "$text{'log_clf'}<br>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=logclear value=1 %s>\n",
	$miniserv{'logclear'} ? "checked" : "";
print &text('log_clear',
	"<input name=logtime value='$miniserv{'logtime'}' size=10>"),"<br>\n";

print "<table cellpadding=0 cellspacing=0><tr> <td valign=top>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=radio name=uall value=1 %s> %s<br>\n",
	$gconfig{'logusers'} ? '' : 'checked', $text{'log_uall'};
printf "&nbsp;&nbsp;&nbsp;<input type=radio name=uall value=0 %s> %s</td>\n",
	$gconfig{'logusers'} ? 'checked' : '', $text{'log_users'};
map { $users{$_}++ } split(/\s+/, $gconfig{'logusers'});
print "<td valign=top><select multiple size=3 name=users>\n";
foreach $u (&foreign_call("acl", "list_users")) {
	printf "<option %s>%s\n", $users{$u->{'name'}} ? 'selected' : '',
				  $u->{'name'};
	}
print "</select></td></tr></table>\n";

print "<table cellpadding=0 cellspacing=0><tr> <td valign=top>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=radio name=mall value=1 %s> %s<br>\n",
	$gconfig{'logmodules'} ? '' : 'checked', $text{'log_mall'};
printf "&nbsp;&nbsp;&nbsp;<input type=radio name=mall value=0 %s> %s</td>\n",
	$gconfig{'logmodules'} ? 'checked' : '', $text{'log_modules'};
map { $mods{$_}++ } split(/\s+/, $gconfig{'logmodules'});
print "<td valign=top><select multiple size=5 name=modules>\n";
foreach $m (&foreign_call("acl", "list_modules")) {
	%minfo = &get_module_info($m);
	if (-r "../$m/log_parser.pl") {
		printf "<option value=%s %s>%s\n",
			$m, $mods{$m} ? 'selected' : '', $minfo{'desc'};
		}
	}
print "</select></td></tr></table>\n";

print "&nbsp;&nbsp;&nbsp;";
printf "<input type=checkbox name=logfiles value=1 %s> %s<br>\n",
	$gconfig{'logfiles'} ? 'checked' : '',
	$text{'log_files'};

print "&nbsp;&nbsp;&nbsp;$text{'log_perms'}\n";
printf "<input type=radio name=perms_def value=1 %s> %s\n",
	$gconfig{'logperms'} ? "" : "checked", $text{'default'};
printf "<input type=radio name=perms_def value=0 %s>\n",
	$gconfig{'logperms'} ? "checked" : "";
printf "<input name=perms size=5 value='%s'><br>\n",
	$gconfig{'logperms'};

print "</td> </tr></table><br>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

