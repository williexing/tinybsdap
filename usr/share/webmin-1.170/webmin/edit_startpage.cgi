#!/usr/local/bin/perl
# edit_startpage.cgi
# Startpage config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'startpage_title'}, "");

print $text{'startpage_intro2'},"<p>\n";

print "<form action=change_startpage.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'startpage_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'startpage_nocol'}</b></td> <td>\n";
printf "<input name=nocols_def type=radio value=1 %s> %s\n",
	$gconfig{'nocols'} ? '' : 'checked', $text{'default'};
printf "<input name=nocols_def type=radio value=0 %s>\n",
	$gconfig{'nocols'} ? 'checked' : '';
printf "<input name=nocols size=5 value='%s'></td> </tr>\n",
	$gconfig{'nocols'};

print "<tr> <td><b>$text{'startpage_tabs'}</b></td> <td>\n";
printf "<input name=notabs type=radio value=0 %s> %s\n",
	$gconfig{'notabs'} ? '' : 'checked', $text{'yes'};
printf "<input name=notabs type=radio value=1 %s> %s</td> </tr>\n",
	$gconfig{'notabs'} ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'startpage_deftab'}</b></td> <td>\n";
$cat = defined($gconfig{'deftab'}) ? $gconfig{'deftab'} : 'webmin';
print "<select name=deftab>\n";
foreach $t (keys %text) {
	next if ($t !~ /^category_(\S*)$/);
	$cats{$1} = $text{$t};
	}
&read_file("$config_directory/webmin.catnames", \%catnames);
foreach $c (keys %catnames) {
	$cats{$c} = $catnames{$c};
	}
foreach $c (sort { $cats{$a} cmp $cats{$b} } keys %cats) {
	printf "<option value='%s' %s>%s\n",
		$c, $cat eq $c ? 'selected' : '', $cats{$c};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'startpage_alt'}</b></td> <td>\n";
printf "<input name=alt_startpage type=radio value=1 %s> %s\n",
	$gconfig{'alt_startpage'} ? 'checked' : '', $text{'yes'};
printf "<input name=alt_startpage type=radio value=0 %s> %s</td> </tr>\n",
	$gconfig{'alt_startpage'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'startpage_nohost'}</b></td> <td>\n";
printf "<input name=nohostname type=radio value=0 %s> %s\n",
	$gconfig{'nohostname'} ? '' : 'checked', $text{'yes'};
printf "<input name=nohostname type=radio value=1 %s> %s</td> </tr>\n",
	$gconfig{'nohostname'} ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'startpage_gotoone'}</b></td> <td>\n";
printf "<input name=gotoone type=radio value=1 %s> %s\n",
	$gconfig{'gotoone'} ? 'checked' : '', $text{'yes'};
printf "<input name=gotoone type=radio value=0 %s> %s</td> </tr>\n",
	$gconfig{'gotoone'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'startpage_gotomodule'}</b></td>\n";
print "<td><select name=gotomodule>\n";
printf "<option value='' %s>%s\n",
	$gconfig{'gotomodule'} ? "" : "selected", $text{'startpage_gotonone'};
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } &get_all_module_infos()) {
	printf "<option value=%s %s>%s\n",
		$m->{'dir'}, $gconfig{'gotomodule'} eq $m->{'dir'} ?
				'selected' : '', $m->{'desc'};
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

