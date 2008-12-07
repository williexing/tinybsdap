#!/usr/local/bin/perl
# edit_mods.cgi
# Form for installing and removing modules

require './webmin-lib.pl';
&ui_print_header(undef, $text{'mods_title'}, "");
@mlist = sort { $a->{'desc'} cmp $b->{'desc'} }
	      grep { &check_os_support($_) } &get_all_module_infos();

# Display installation form
print "<table width=100%><tr><td valign=top>\n";
print "$text{'mods_desc1'}</td><td valign=top>";

print "<form action=install_mod.cgi enctype=multipart/form-data method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'mods_install'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";
print "<input type=radio name=source value=0 checked> $text{'mods_local'}\n";
print "<input name=file size=40>\n";
print &file_chooser_button("file", 0),"<br>\n";

print "<input type=radio name=source value=1> $text{'mods_uploaded'}\n";
print "<input name=upload type=file size=30><br>\n";

print "<input type=radio name=source value=2> $text{'mods_ftp'}\n";
print "<input name=url size=40><br>\n";

print "<input type=radio name=source value=3>\n";
if ($config{'standard_url'}) {
	print "$text{'mods_standard2'}\n";
	}
else {
	print &text('mods_standard',"http://www.webmin.com/standard.html"),"\n";
	}
print "<input name=standard size=20> ",
      &standard_chooser_button("standard"),"<br>\n";

print "<input type=radio name=source value=4> $text{'mods_third'}\n";
print "<input name=third size=40> ",
      &third_chooser_button("third"),"<p>\n";

print "<input type=checkbox name=nodeps value=1> $text{'mods_nodeps'}<br>\n";
print "<input type=radio name=grant value=0 checked> $text{'mods_grant2'}\n";
print "<input name=grantto size=30 value='$base_remote_user'><br>\n";
print "<input type=radio name=grant value=1> $text{'mods_grant1'}\n";
print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'mods_installok'}\">\n";
print "</form></td></tr></table> <hr>\n";

# Display cloning form
print "<table width=100%><tr><td valign=top>\n";
print "$text{'mods_desc2'}</td> <td valign=top>";

print "<form action=clone_mod.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'mods_clone'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td nowrap><b>$text{'mods_cname'}</b></td>\n";
print "<td><select name=mod>\n";
foreach $m (@mlist) {
	if ($m->{'dir'} ne 'webmin' && !$m->{'clone'}) {
		printf "<option value='%s'>%s\n",
			$m->{'dir'}, $m->{'desc'};
		}
	}
closedir(DIR);
print "</select></td> </tr>\n";
print "<tr> <td nowrap><b>$text{'mods_cnew'}</b></td>\n";
print "<td><input name=desc size=30></td> </tr>\n";
print "<tr> <td nowrap><b>$text{'mods_ccat'}</b></td>\n";
print "<td><select name=cat>\n";
print "<option value=* selected>$text{'mods_csame'}\n";
foreach $t (keys %text) {
	if ($t =~ /^category_(.*)/) {
		$cats{$1} = $text{$t};
		}
	}
&read_file("$config_directory/webmin.catnames", \%catnames);
foreach $t (keys %catnames) {
	$cats{$t} = $catnames{$t};
	}
foreach $c (sort { $cats{$a} cmp $cats{$b} } keys %cats) {
	print "<option value=$c>$cats{$c}\n";
	}
print "</select></td> </tr>\n";
print "</table></td></tr> </table>\n";
print "<input type=submit value=\"$text{'mods_cloneok'}\">\n";
print "</form></td></tr></table> <hr>\n";


# Display deletion form
print "<table width=100%><tr>\n";
print "<td valign=top>$text{'mods_desc3'}</td> <td>\n";
print "<form action=delete_mod.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td valign=top><b>$text{'mods_delete'}</b></td> </tr>\n";
print "<tr> <td $cb><select multiple width=300 name=mod size=10>\n";
$version = &get_webmin_version();
local $home = $root_directory eq '/usr/local/webadmin';
foreach $m (@mlist) {
	if ($m->{'dir'} ne 'webmin' && &check_os_support($m)) {
		local @st = stat("$root_directory/$m->{'dir'}");
		local @tm = localtime($st[9]);
		local $vstr = $m->{'version'} == $version ? "" :
			      $m->{'version'} ? "(v. $m->{'version'})" :
			      $home ? "" :
			      sprintf "(%d/%d/%d)",
				      $tm[3], $tm[4]+1, $tm[5]+1900;
		printf "<option value='%s'>%s %s\n",
			$m->{'dir'}, $m->{'desc'}, $vstr;
		}
	}
print "</select></td> </tr></table>\n";
print "<input type=submit value=\"$text{'mods_deleteok'}\">\n";
print "</form></td></tr></table>\n";

&ui_print_footer("", $text{'index_return'});

