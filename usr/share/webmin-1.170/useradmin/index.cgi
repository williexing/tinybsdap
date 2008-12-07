#!/usr/local/bin/perl

require './user-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("passwd group shadow gshadow", "man"));
$formno = 0;
%access = &get_module_acl();

# Get the user and group lists
@allulist = &list_users();
@ulist = &list_allowed_users(\%access, \@allulist);
@allglist = &list_groups();
@glist = &list_allowed_groups(\%access, \@allglist);
foreach $g (@allglist) {
	$usedgid{$g->{'gid'}} = $g;
	}

if (@ulist > $config{'display_max'}) {
	# Display user search form
	print "<b>$text{'index_toomany'}</b><br>\n";
	print "<form action=search_user.cgi>\n";
	print &hlink("<b>$text{'index_find'}</b>","findform"),
	      " <select name=field>\n";
	print "<option value=user selected>$text{'user'}\n";
	print "<option value=real>$text{'real'}\n";
	print "<option value=shell>$text{'shell'}\n";
	print "<option value=home>$text{'home'}\n";
	print "<option value=uid>$text{'uid'}\n";
	print "<option value=gid>$text{'gid'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=4>$text{'index_contains'}\n";
	print "<option value=1>$text{'index_matches'}\n";
	print "<option value=2>$text{'index_nequals'}\n";
	print "<option value=5>$text{'index_ncontains'}\n";
	print "<option value=3>$text{'index_nmatches'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></form>\n";
	$formno++;
	}
elsif (@ulist) {
	# Display a table of all users
	if ($config{'sort_mode'} == 1) {
		@ulist = sort { $a->{'user'} cmp $b->{'user'} } @ulist;
		}
	elsif ($config{'sort_mode'} == 2) {
		@ulist = sort { lc($a->{'real'}) cmp lc($b->{'real'}) } @ulist;
		}
	elsif ($config{'sort_mode'} == 3) {
		@ulist = sort { @wa = split(/\s+/, $a->{'real'});
				@wb = split(/\s+/, $b->{'real'});
				lc($wa[@wa-1]) cmp lc($wb[@wb-1]) } @ulist;
		}
	elsif ($config{'sort_mode'} == 4) {
		@ulist = sort { $a->{'shell'} cmp $b->{'shell'} } @ulist;
		}
	elsif ($config{'sort_mode'} == 5) {
		@ulist = sort { $a->{'uid'} <=> $b->{'uid'} } @ulist;
		}
	elsif ($config{'sort_mode'} == 6) {
		@ulist = sort { $a->{'home'} cmp $b->{'home'} } @ulist;
		}
	if ($access{'icons'}) {
		# Show an icon for each user
		print "<h3>$text{'index_users'}</h3>\n";
		&show_user_buttons();
		local @icons = map { "images/user.gif" } @ulist;
		local @links = map { "edit_user.cgi?num=$_->{'num'}" } @ulist;
		local @titles = map { $_->{'user'} } @ulist;
		&icons_table(\@links, \@titles, \@icons, 5);
		}
	elsif ($config{'display_mode'} == 2) {
		# Show usernames under groups
		foreach $u (@ulist) {
			push(@{$ug{$u->{'gid'}}}, $u);
			}
		&show_user_buttons();
		print "<table width=100% border>\n";
		print "<tr $tb> <td><b>$text{'index_ugroup'}</b></td> ",
		      "<td><b>$text{'index_users'}</b></td> </tr>\n";
		foreach $g (keys %ug) {
			print "<tr $cb> <td width=20%><b>",
			      &html_escape($usedgid{$g}->{'group'}),
			      "</b></td>\n";
			print "<td width=80%><table width=100% ",
			      "cellpadding=0 cellspacing=0>\n";
			$i = 0;
			foreach $u (@{$ug{$g}}) {
				if ($i%4 == 0) { print "<tr>\n"; }
				print "<td width=25%><a href=\"edit_user.cgi?",
				      "num=$u->{'num'}\">",
				      &html_escape($u->{'user'}),"</a></td>\n";
				if ($i%4 == 3) { print "</tr>\n"; }
				$i++;
				}
			print "</table></td> </tr>\n";
			}
		print "</table>\n";
		}
	elsif ($config{'display_mode'} == 1) {
		# Show names, real names, home dirs and shells
		print "<h3>$text{'index_users'}</h3>\n";
		&show_user_buttons();
		&users_table(\@ulist);
		}
	else {
		# Just show names
		&show_user_buttons();
		print "<table width=100% border>\n";
		print "<tr $tb> <td><b>$text{'index_users'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		for($i=0; $i<@ulist; $i++) {
			if ($i%4 == 0) { print "<tr>\n"; }
			print "<td width=25%><a href=\"edit_user.cgi?",
			      "num=$ulist[$i]->{'num'}\">",
			      &html_escape($ulist[$i]->{'user'}),"</a></td>\n";
			if ($i%4 == 3) { print "</tr>\n"; }
			}
		print "</table></td> </tr></table>\n";
		}
	}
elsif ($access{'ucreate'}) {
	if (@allulist) {
		print "<b>$text{'index_notusers'}</b>. <p>\n";
		}
	else {
		print "<b>$text{'index_notusers2'}</b>. <p>\n";
		}
	}
&show_user_buttons();
print "<p>\n";

if (@glist > $config{'display_max'}) {
	# Display group search form
	print "<hr>\n";
	print "<b>$text{'index_gtoomany'}</b><br>\n";
	print "<form action=search_group.cgi>\n";
	print &hlink("<b>$text{'index_gfind'}</b>","gfindform"),
	      " <select name=field>\n";
	print "<option value=group selected>$text{'gedit_group'}\n";
	print "<option value=members>$text{'gedit_members'}\n";
	print "<option value=gid>$text{'gedit_gid'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=4>$text{'index_contains'}\n";
	print "<option value=1>$text{'index_matches'}\n";
	print "<option value=2>$text{'index_nequals'}\n";
	print "<option value=5>$text{'index_ncontains'}\n";
	print "<option value=3>$text{'index_nmatches'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></form>\n";
	$formno++;
	}
elsif (@glist) {
	print "<hr>\n";
	if ($config{'sort_mode'} == 5) {
		@glist = sort { $a->{'gid'} <=> $b->{'gid'} } @glist;
		}
	elsif ($config{'sort_mode'} == 1) {
		@glist = sort { $a->{'group'} cmp $b->{'group'} } @glist;
		}
	if ($access{'icons'}) {
		# Show an icon for each group
		print "<h3>$text{'index_groups'}</h3>\n";
		&show_group_buttons();
		local @icons = map { "images/group.gif" } @glist;
		local @links = map { "edit_group.cgi?num=$_->{'num'}" } @glist;
		local @titles = map { $_->{'group'} } @glist;
		&icons_table(\@links, \@titles, \@icons, 5);
		}
	elsif ($config{'display_mode'} == 1) {
		# Display group name, ID and members
		print "<h3>$text{'index_groups'}</h3>\n";
		&show_group_buttons();
		&groups_table(\@glist);
		}
	else {
		# Just display group names
		&show_group_buttons();
		print "<table width=100% border>\n";
		print "<tr $tb> <td><b>$text{'index_groups'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		for($i=0; $i<@glist; $i++) {
			if ($i%4 == 0) { print "<tr>\n"; }
			print "<td width=25%><a href=\"edit_group.cgi?",
			      "num=$glist[$i]->{'num'}\">",
			      &html_escape($glist[$i]->{'group'}),"</a></td>\n";
			if ($i%4 == 3) { print "</tr>\n"; }
			}
		print "</table></td> </tr></table>\n";
		}
	}
elsif ($access{'gcreate'} == 1) {
	print "<hr>\n";
	if (@allglist) {
		print "<b>$text{'index_notgroups'}</b>. <p>\n";
		}
	else {
		print "<b>$text{'index_notgroups2'}</b>. <p>\n";
		}
	}
&show_group_buttons();

if ($access{'logins'}) {
	print "<hr>\n";
	print "<table width=100%><tr>\n";
	print "<form action=list_logins.cgi>\n";
	print "<td><input type=submit value=\"$text{'index_logins'}\">\n";
	print "<input name=username size=8> ",
	      &user_chooser_button("username",0,$formno),"</td></form>\n";

	if (defined(&logged_in_users)) {
		print "<form action=list_who.cgi>\n";
		print "<td align=right><input type=submit ",
		      "value=\"$text{'index_who'}\"></td></form>\n";
		}
	print "</tr></table>\n";
	}

&ui_print_footer("/", $text{'index'});
 
sub show_user_buttons
{
if ($access{'ucreate'}) {
	local $cancreate;
	if ($access{'hiuid'} && !$access{'umultiple'}) {
		foreach $u (@allulist) {
			$useduid{$u->{'uid'}}++;
			}
		for($i=int($access{'lowuid'}); $i<=$access{'hiuid'}; $i++) {
			if (!$useduid{$i}) {
				$cancreate = 1;
				last;
				}
			}
		}
	else { $cancreate = 1; }
	if ($cancreate) {
		print "<a href=\"edit_user.cgi\">",
		      "$text{'index_createuser'}</a>&nbsp;&nbsp;\n";
		}
	else {
		print "$text{'index_nomoreusers'}&nbsp;&nbsp;\n";
		}
	}
print "<a href=\"batch_form.cgi\">$text{'index_batch'}</a>&nbsp;&nbsp;\n"
	if ($access{'batch'});
print "<a href=\"export_form.cgi\">$text{'index_export'}</a>&nbsp;&nbsp;\n"
	if ($access{'export'});
print "<br>\n";
}

sub show_group_buttons
{
if ($access{'gcreate'} == 1) {
	local $cancreate;
	if ($access{'higid'} && !$access{'gmultiple'}) {
		for($i=int($access{'lowgid'}); $i<=$access{'higid'}; $i++) {
			if (!$usedgid{$i}) {
				$cancreate = 1;
				last;
				}
			}
		}
	else { $cancreate = 1; }
	if ($cancreate) {
		print "<a href=\"edit_group.cgi\">$text{'index_creategroup'}</a> <br>\n";
		}
	else {
		print "$text{'index_nomoregroups'}<br>\n";
		}
	}
}

