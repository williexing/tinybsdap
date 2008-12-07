#!/usr/bin/perl
# edit_serv.cgi
# Edit or create a webmin server

require './servers-lib.pl';
&ReadParse();
$access{'edit'} || &error($text{'edit_ecannot'});

if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	$s = &get_server($in{'id'});
	&can_use_server($s) || &error($text{'edit_ecannot'});
	}

print "<form action=save_serv.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=id value='$in{'id'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_host'}</b></td>\n";
print "<td><input name=host size=30 value='$s->{'host'}'></td>\n";

print "<td><b>$text{'edit_port'}</b></td>\n";
print "<td><input name=port size=5 value='$s->{'port'}'></td> </tr>\n";

print "<tr> <td><b>$text{'edit_type'}</b></td> <td><select name=type>\n";
foreach $t (@server_types) {
	printf "<option value='%s' %s>%s\n",
		$t->[0], $t->[0] eq $s->{'type'} ? 'selected' : '',
		$t->[1];
	}
print "</select></td>\n";

print "<td><b>$text{'edit_ssl'}</b></td> <td>\n";
printf "<input type=radio name=ssl value=1 %s> $text{'yes'}\n",
	$s->{'ssl'} ? 'checked' : '';
printf "<input type=radio name=ssl value=0 %s> $text{'no'}</td> </tr>\n",
	$s->{'ssl'} ? '' : 'checked';

$s->{'desc'} =~ s/"/&quot;/g;
print "<tr> <td><b>$text{'edit_desc'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=desc_def value=1 %s> %s\n",
	$s->{'desc'} ? '' : 'checked', $text{'edit_desc_def'};
printf "<input type=radio name=desc_def value=0 %s>\n",
	$s->{'desc'} ? 'checked' : '';
printf "<input name=desc size=40 value=\"%s\"></td> </tr>\n", $s->{'desc'};

@groups = &unique(map { split(/\t/, $_->{'group'}) } &list_servers());
print "<tr> <td valign=top><b>$text{'edit_group'}</b></td> <td colspan=3>\n";
%ingroups = map { $_, 1 } split(/\t/, $s->{'group'});
print "<table width=100%>\n";
foreach $g (@groups) {
	print "<tr>\n" if ($i%4 == 0);
	printf "<td width=25%%><input type=checkbox name=group value='%s' %s> %s</td>\n",
		$g, $ingroups{$g} ? "checked" : "", $g;
	print "</tr>\n" if ($i++%4 == 3);
	}
print "<tr>\n" if ($i%4 == 0);
print "<td width=25%>$text{'edit_new'} <input name=newgroup size=10></td>\n";
print "</tr>\n" if ($i++%4 == 3);
print "</table></td> </tr>\n";

$mode = $s->{'autouser'} ? 2 : $s->{'user'} ? 1 : 0;
print "<tr> <td valign=top><b>$text{'edit_link'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mode value=0 %s> $text{'edit_mode0'}<br>\n",
	$mode == 0 ? 'checked' : '';
printf "<input type=radio name=mode value=1 %s> $text{'edit_mode1'}\n",
	$mode == 1 ? 'checked' : '';
printf "%s <input name=user size=10 value='%s'>\n",
	$text{'edit_user'}, $mode == 1 ? $s->{'user'} : "";
printf "%s <input type=password name=pass size=10 value='%s'><br>\n",
	$text{'edit_pass'}, $s->{'pass'};
printf "<input type=radio name=mode value=2 %s> $text{'edit_mode2'}\n",
	$mode == 2 ? 'checked' : '';
print "</td> </tr>\n";

print "<tr> <td><b>$text{'edit_fast'}</b></td>\n";
if ($in{'new'} || $s->{'fast'} == 2) {
	print "<td><input type=radio name=fast value=1> $text{'yes'}\n";
	print "<input type=radio name=fast value=2 checked> $text{'edit_auto'}\n";
	print "<input type=radio name=fast value=0> $text{'no'}</td>\n";
	}
else {
	printf "<td><input type=radio name=fast value=1 %s> %s\n",
		$s->{'fast'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=fast value=0 %s> %s</td>\n",
		$s->{'fast'} ? '' : 'checked', $text{'no'};
	}
print "</tr>\n";

if ($s->{'user'} && $config{'show_status'}) {
	sub status_error
	{
	$status_error_msg = join("", @_);
	}
	&remote_error_setup(\&status_error);
	eval {
		$SIG{'ALRM'} = sub { die "alarm\n" };
		alarm(10);
		&remote_foreign_require($s->{'host'}, "webmin","webmin-lib.pl");
		if ($status_error_msg) {
			# Failed to connect
			$msg = $status_error_msg;
			}
		else {
			# Connected - get status
			$msg = &text('edit_version',
				&remote_foreign_call($s->{'host'}, "webmin",
						     "get_webmin_version"));
			}
		alarm(0);
		};
	if ($@) {
		$msg = $text{'edit_timeout'};
		}

	print "<tr> <td><b>$text{'edit_status'}</b></td>\n";
	print "<td colspan=3>$msg</td> </tr>\n";
	}

print "</table></td></tr></table>\n";

print "<table width=100%><tr><td>\n";
print "<input type=submit value=\"$text{'save'}\"></td>";
if (!$in{'new'}) {
	print "<td align=right>\n";
	print "<input type=submit name=delete value=Delete></td>";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

