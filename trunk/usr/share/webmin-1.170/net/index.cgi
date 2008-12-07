#!/usr/bin/perl
# index.cgi
# Display a menu of various network screens

require './net-lib.pl';
mountrw();

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("ifconfig hosts resolve.conf nsswitch.conf", "man"));

foreach $i ('ifcs', 'routes', 'dns', 'hosts') {
	if ($access{$i}) {
		push(@links, "list_${i}.cgi");
		push(@titles, $text{"${i}_title"});
		push(@icons, "images/${i}.gif");
		}
	}
&icons_table(\@links, \@titles, \@icons);

if (defined(&apply_network) && $access{'apply'}) {
	# Allow the user to apply the network config
	print "<hr>\n";
	print "<form action=apply.cgi>\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value='$text{'index_apply'}'></td>\n";
	print "<td>$text{'index_applydesc'}</td>\n";
	print "</tr></table></form>\n";
	}
&ui_print_footer("/", $text{'index'});

