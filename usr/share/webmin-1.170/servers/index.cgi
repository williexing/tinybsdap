#!/usr/bin/perl
# Display a list of other webmin servers

require './servers-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

@servers = grep { &can_use_server($_) }
	   sort { $a->{'host'} cmp $b->{'host'} } &list_servers();
if ($config{'sort_mode'} == 1) {
	@servers = sort { $a->{'host'} cmp $b->{'host'} } @servers;
	}
elsif ($config{'sort_mode'} == 2) {
	@servers = sort { lc($a->{'desc'} ? $a->{'desc'} : $a->{'host'}) cmp
		   lc($b->{'desc'} ? $b->{'desc'} : $b->{'host'}) } @servers;
	}
elsif ($config{'sort_mode'} == 3) {
	@servers = sort { $a->{'type'} cmp $b->{'type'} } @servers;
	}
elsif ($config{'sort_mode'} == 4) {
	@servers = sort { &to_ipaddress($a->{'host'}) cmp
			  &to_ipaddress($b->{'host'}) } @servers;
	}
elsif ($config{'sort_mode'} == 5) {
	@servers = sort { $a->{'group'} cmp $b->{'group'} } @servers;
	}
if (@servers && $config{'display_mode'}) {
	print "<a href='edit_serv.cgi?new=1'>$text{'index_add'}</a> <br>\n"
	    if $access{'edit'};
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_host'}</b></td>\n";
	print "<td><b>$text{'index_desc'}</b></td>\n";
	print "<td><b>$text{'index_group'}</b></td>\n";
	print "<td><b>$text{'index_os'}</b></td> </tr>\n";
	foreach $s (@servers) {
		print "<tr $cb>\n";
		print "<td><table cellpadding=0 cellspacing=0 width=100%><tr>\n";
		if ($s->{'user'} || $s->{'autouser'}) {
			print "<td><a href='link.cgi/$s->{'id'}/'>\n";
			}
		else {
			print "<td><a href=".&make_url($s).">\n";
			}
		print "$s->{'host'}:$s->{'port'}</a></td>\n";
		print "<td align=right>";
		if ($s->{'autouser'} && &logged_in($s)) {
			print "<a href='logout.cgi?id=$s->{'id'}'>($text{'index_logout'})</a>\n";
			}
		if ($access{'edit'}) {
			print "<a href='edit_serv.cgi?id=$s->{'id'}'>($text{'index_edit'})</a>\n";
			}
		print "</td> </tr></table></td>\n";
		print "<td>$s->{'desc'}&nbsp;</td>\n";
		print "<td>",$s->{'group'} ? $s->{'group'} :
					     $text{'index_none'},"</td> <td>\n";
		foreach $t (@server_types) {
			if ($t->[0] eq $s->{'type'}) {
				print $t->[1];
				}
			}
		print "</td> </tr>\n";
		}
	print "</table>\n";
	}
elsif (@servers) {
	if ($access{'edit'}) {
		print "<a href='edit_serv.cgi?new=1'>$text{'index_add'}</a><br>\n";
		@titles = map { &make_iconname($_)."</a> <a href='edit_serv.cgi?id=$_->{'id'}'>(".$text{'index_edit'}.")" } @servers;
		}
	else {
		@titles = map { &make_iconname($_) } @servers;
		}
	@icons = map { "images/$_->{'type'}.gif" } @servers;
	@links = map { $_->{'user'} || $_->{'autouser'} ?
			"link.cgi/$_->{'id'}/" : &make_url($_) } @servers;
	&icons_table(\@links, \@titles, \@icons, undef, "target=_top");
	}
else {
	print "<b>$text{'index_noservers'}</b> <p>\n";
	}

print "<a href='edit_serv.cgi?new=1'>$text{'index_add'}</a> <p>\n"
    if $access{'edit'};

$myip = &get_my_address();
$myscan = &address_to_broadcast($myip, 1) if ($myip);
print "<hr>\n",
    "<table width=100%>\n",
    "<form action=find.cgi>\n",
    "<tr> <td><input type=submit value=\"$text{'index_broad'}\"></td>\n",
    "<td>$text{'index_findmsg'}</td> </tr>\n",
    "</form>\n",
    "<form action=find.cgi>\n",
    "<tr> <td><input type=submit value=\"$text{'index_scan'}\"></td>\n",
    "<td>",&text('index_scanmsg',"<input name=scan size=15 value='$myscan'>"),"</td> </tr>\n",
    "</form>\n",
    "</table>\n"
    if $access{'find'};

&ui_print_footer("/", $text{'index'});

sub make_url
{
return sprintf "http%s://%s:%d/",
	$_[0]->{'ssl'} ? 's' : '', $_[0]->{'host'}, $_[0]->{'port'};
}

sub make_iconname
{
local $rv;
if ($_[0]->{'desc'}) {
	$rv = $_[0]->{'desc'};
	}
else {
	$rv = "$_[0]->{'host'}:$_[0]->{'port'}";
	}
if (&logged_in($_[0])) {
	$rv .= "</a> <a href='logout.cgi?id=$_->{'id'}'>(".$text{'index_logout'}.")";
	}
return $rv;
}

