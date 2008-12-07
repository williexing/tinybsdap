
do 'firewall-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_tables'}</b></td> <td colspan=3>\n";
local $t;
foreach $t (@known_tables) {
	printf "<input type=checkbox name=%s value=1 %s> %s<br>\n",
		$t, $_[0]->{$t} ? "checked" : "", $text{'index_table_'.$t};
	}
print "</td> </tr>\n";

local ($f, $i);
foreach $f ("apply", "unapply", "bootup", "setup") {
	print "<tr>\n" if ($i%2 == 0);
	print "<td><b>",$text{'acl_'.$f},"</b></td> <td>\n";
	printf "<input type=radio name=%s value=1 %s> %s\n",
		$f, $_[0]->{$f} ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=%s value=0 %s> %s</td>\n",
		$f, $_[0]->{$f} ? "" : "checked", $text{'no'};
	print "</tr>\n" if ($i++%2 == 1);
	}
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
local $t;
foreach $t (@known_tables) {
	$_[0]->{$t} = $in{$t};
	}
local $f;
foreach $f ("apply", "unapply", "bootup", "setup") {
	$_[0]->{$f} = $in{$f};
	}
}

