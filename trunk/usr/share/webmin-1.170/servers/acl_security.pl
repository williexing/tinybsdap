
require 'servers-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the servers module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_servers'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=servers_def value=1 %s> %s\n",
        $_[0]->{'servers'} eq '*' ? 'checked' : '', $text{'acl_sall'};
printf "<input type=radio name=servers_def value=0 %s> %s<br>\n",
        $_[0]->{'servers'} eq '*' ? '' : 'checked', $text{'acl_ssel'};
print "<select name=servers multiple size=4 width=15>\n";
local @servers = sort { $a->{'host'} cmp $b->{'host'} } &list_servers();
local ($z, %zcan);
map { $zcan{$_}++ } split(/\s+/, $_[0]->{'servers'});
foreach $z (sort { $a->{'value'} cmp $b->{'value'} } @servers) {
        printf "<option value='%s' %s>%s\n",
                $z->{'id'},
                $zcan{$z->{'host'}} || $zcan{$z->{'id'}} ? "selected" : "",
                $z->{'host'} ;
        }
print "</select></td></tr>\n";

print "<tr> <td><b>$text{'acl_edit'}</b></td> <td>\n";
printf "<input type=radio name=edit value=1 %s> $text{'yes'}\n",
        $_[0]->{'edit'} ? "checked" : "";
printf "<input type=radio name=edit value=0 %s> $text{'no'}</td>\n",
        $_[0]->{'edit'} ? "" : "checked";

print "<td><b>$text{'acl_find'}</b></td> <td>\n";
printf "<input type=radio name=find value=1 %s> $text{'yes'}\n",
        $_[0]->{'find'} ? "checked" : "";
printf "<input type=radio name=find value=0 %s> $text{'no'}</td> </tr>\n",
        $_[0]->{'find'} ? "" : "checked";


}

# acl_security_save(&options)
# Parse the form for security options for the servers module
sub acl_security_save
{
if ($in{'servers_def'}) {
        $_[0]->{'servers'} = "*";
        }
else {
        $_[0]->{'servers'} = join(" ", split(/\0/, $in{'servers'}));
        }
$_[0]->{'edit'} = $in{'edit'};
$_[0]->{'find'} = $in{'find'};
}

