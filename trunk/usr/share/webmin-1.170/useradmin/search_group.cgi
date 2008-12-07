#!/usr/local/bin/perl
# search_group.cgi
# Search the group file, and display a list of results

require './user-lib.pl';
&ReadParse();
@glist = &list_groups();
$m = $in{'match'};
$w = $in{'what'};
for($i=0; $i<@glist; $i++) {
	$g = $glist[$i];
	$f = $g->{$in{'field'}};
	if ($m == 0 && $f eq $w ||
	    $m == 1 && eval { $f =~ /$w/i } ||
	    $m == 4 && index($f, $w) >= 0 ||
	    $m == 2 && $f ne $w ||
	    $m == 3 && eval { $f !~ /$w/i } ||
	    $m == 5 && index($f, $w) < 0) {
		push(@match, $g);
		}
	}
if (@match == 1) {
	&redirect("edit_group.cgi?num=".$match[0]->{'num'});
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@match == 0) {
		print "<p><b>$text{'search_gnotfound'}</b>. <p>\n";
		}
	else {
		&groups_table(\@match);
		}
	&ui_print_footer("", $text{'index_return'});
	}

