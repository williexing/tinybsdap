#!/usr/local/bin/perl
# edit_ui.cgi
# Edit user interface options

require './webmin-lib.pl';
&ui_print_header(undef, $text{'ui_title'}, "");

print $text{'ui_desc'},"<p>\n";
print "<form action=change_ui.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'ui_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

for($i=0; $i<@cs_names; $i++) {
	$cd = $cs_codes[$i];
	print "<tr> <td><b>$cs_names[$i]</b></td>\n";
	printf "<td><input type=radio name=${cd}_def value=1 %s> %s\n",
		defined($gconfig{$cd}) ? "" : "checked",
		$text{'ui_default'};
	printf "&nbsp;&nbsp;<input type=radio name=${cd}_def value=0 %s> %s\n",
		defined($gconfig{$cd}) ? "checked" : "",
		$text{'ui_rgb'};
	print "<input name=${cd}_rgb size=8 value='$gconfig{$cd}'>\n";
	print "</td> </tr>\n";
	}

print "<tr> <td><b>$text{'ui_texttitles'}</b></td>\n";
printf "<td><input type=radio name=texttitles value=1 %s> %s\n",
	$gconfig{'texttitles'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=texttitles value=0 %s> %s</td> </tr>\n",
	$gconfig{'texttitles'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'ui_sysinfo'}</b></td>\n";
print "<td><select name=sysinfo>\n";
foreach $m (0, 1, 4, 2, 3) {
	printf "<option value=%s %s> %s\n",
		$m, $gconfig{'sysinfo'} == $m ? 'selected' : '',
		$text{'ui_sysinfo'.$m};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'ui_hostnamemode'}</b></td>\n";
print "<td><select name=hostnamemode>\n";
foreach $m (0 .. 3) {
	printf "<option value=%s %s>%s\n",
		$m, $gconfig{'hostnamemode'} == $m ? "selected" : "",
		$text{'ui_hnm'.$m};
	}
print "</select>\n";
printf "<input name=hostnamedisplay size=20 value='%s'>\n",
	$gconfig{'hostnamedisplay'};
print "</td> </tr>\n";

print "<tr> <td><b>$text{'ui_feedback'}</b></td>\n";
printf "<td><input type=radio name=feedback_def value=1 %s> %s\n",
	$gconfig{'feedback_to'} ? "" : "checked", $webmin_feedback_address;
printf "<input type=radio name=feedback_def value=0 %s>\n",
	$gconfig{'feedback_to'} ? "checked" : "";
printf "<input name=feedback size=20 value='%s'></td> </tr>\n",
	$gconfig{'feedback_to'};

print "<tr> <td><b>$text{'ui_feedbackmode'}</b></td>\n";
printf "<td><input type=radio name=nofeedbackcc value=0 %s> %s\n",
	$gconfig{'nofeedbackcc'} == 0 ? "checked" : "", $text{'yes'};
printf "<input type=radio name=nofeedbackcc value=1 %s> %s\n",
	$gconfig{'nofeedbackcc'} == 1 ? "checked" : "", $text{'ui_feednocc'};
printf "<input type=radio name=nofeedbackcc value=2 %s> %s</td> </tr>\n",
	$gconfig{'nofeedbackcc'} == 2 ? "checked" : "", $text{'no'};

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

