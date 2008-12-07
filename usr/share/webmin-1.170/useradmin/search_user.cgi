#!/usr/local/bin/perl
# search_user.cgi
# Search the password file, and display a list of results

require './user-lib.pl';
&ReadParse();
%access = &get_module_acl();
@ulist = &list_users();
$m = $in{'match'};
$w = $in{'what'};
if ($in{'field'} eq "gid") {
	$w = &my_getgrnam($w) || $w;
	}
for($i=0; $i<@ulist; $i++) {
	$u = $ulist[$i];
	$f = $u->{$in{'field'}};
	if ($m == 0 && $f eq $w ||
	    $m == 1 && eval { $f =~ /$w/i } ||
	    $m == 4 && index($f, $w) >= 0 ||
	    $m == 2 && $f ne $w ||
	    $m == 3 && eval { $f !~ /$w/i } ||
	    $m == 5 && index($f, $w) < 0) {
		push(@match, $u) if (&can_edit_user(\%access, $u));
		}
	}
if (@match == 1) {
	&redirect("edit_user.cgi?num=".$match[0]->{'num'});
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@match == 0) {
		print "<p><b>$text{'search_notfound'}</b>. <p>\n";
		}
	else {
		&users_table(\@match);
		}
	&ui_print_footer("", $text{'index_return'});
	}

