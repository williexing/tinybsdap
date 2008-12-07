#!/usr/local/bin/perl
# edit_os.cgi
# Operating system config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'os_title'}, "");

print $text{'os_desc'},"<br>\n";
print $text{'os_desc2'},"<br>\n";

open(OSLIST, "$root_directory/os_list.txt");
while(<OSLIST>) {
	chop;
	if (/^([^\t]+)\t+([^\t]+)\t+(\S+)\t+(\S+)\t*(.*)$/) {
		push(@list, [ $1, $2, $3, $4, $5 ]);
		}
	}
close(OSLIST);
if (!$gconfig{'real_os_type'}) {
	foreach $o (@list) {
		if ($o->[2] eq $gconfig{'os_type'} &&
		    $o->[3] eq $gconfig{'os_version'}) {
			$gconfig{'real_os_type'} = $o->[0];
			$gconfig{'real_os_version'} = $o->[1];
			last;
			}
		}
	}

print "<form action=change_os.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'os_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'os_curros'}</b></td>\n";
print "<td>$gconfig{'real_os_type'} $gconfig{'real_os_version'}</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'os_new'}</b></td>\n";
print "<td><select name=os size=7>\n";
foreach $o (@list) {
	printf "<option value='%s' %s>%s %s\n",
		join(",", @$o),
		$gconfig{'real_os_type'} eq $o->[0] &&
		$gconfig{'real_os_version'} eq $o->[1] ? "selected" : "",
		$o->[0], $o->[1];
	}
print "</select></td> </tr>\n";

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'os_path'}</b></td>\n";
print "<td><textarea name=path rows=5 cols=30>",
	join("\n", split(/:/, $gconfig{'path'})),
	"</textarea></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'os_ld_path'}</b></td>\n";
print "<td><textarea name=ld_path rows=3 cols=30>",
	join("\n", split(/:/, $gconfig{'ld_path'})),
	"</textarea></td> </tr>\n";

&get_miniserv_config(\%miniserv);
print "<tr> <td valign=top><b>$text{'os_envs'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'os_name'}</b></td> ",
      "<td><b>$text{'os_value'}</b></td> </tr>\n";
$i = 0;
foreach $e (keys %miniserv) {
	if ($e =~ /^env_(\S+)$/ &&
	    $1 ne "WEBMIN_CONFIG" && $1 ne "WEBMIN_VAR") {
		print "<tr $cb>\n";
		print "<td><input name=name_$i size=20 value='$1'></td>\n";
		print "<td><input name=value_$i size=30 ",
		      "value='$miniserv{$e}'></td>\n";
		print "</tr>\n";
		$i++;
		}
	}
print "<td><input name=name_$i size=20></td>\n";
print "<td><input name=value_$i size=30></td>\n";
print "</table></td></tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

