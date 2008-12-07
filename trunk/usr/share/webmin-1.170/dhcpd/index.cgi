#!/usr/bin/perl
# index.cgi
# List all subnets and shared networks

require './dhcpd-lib.pl';

#       -- Property file manipulation
do '../web-lib-props.pl';

mountrw();

$display_max = $config{'display_max'} || 1000000000;
&ReadParse();
$horder = $in{'horder'};
$norder = $in{'norder'};
if ($horder eq "" && open(INDEX, "$module_config_directory/hindex.".$remote_user)) {
	chop($horder = <INDEX>);
	close(INDEX);
	}
if (!$horder) {
	$horder = 0;
	}
if ($norder eq "" && open(INDEX, "$module_config_directory/nindex.".$remote_user)) {
	chop($norder = <INDEX>);
	close(INDEX);
	}
if (!$norder) {
	$norder = 0;
	}
$nocols = $config{'dhcpd_nocols'} ? $config{'dhcpd_nocols'} : 5;
$conf = &get_config();
%access = &get_module_acl();

# Check if dhcpd is installed
if (!-x $config{'dhcpd_path'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("dhcpd", "man", "doc", "howto", "google"));
	print &text('index_dhcpdnotfound', $config{'dhcpd_path'},
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

# Check if it is the right version
@st = stat($config{'dhcpd_path'});
if ($st[7] != $config{'dhcpd_size'} || $st[9] != $config{'dhcpd_mtime'}) {
	# File has changed .. get the version
	local $ver = &get_dhcpd_version(\$out);
	if (!$ver) {
		&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
			&help_search_link("dhcpd", "man", "doc", "howto", "google"));
		print (&text('index_dhcpdver2',$config{'dhcpd_path'},
			     2, 3)),"<p>\n";
		print "<pre>$out</pre>\n";
		&ui_print_footer("/", $text{'index_return'});
		exit;
		}
	$config{'dhcpd_version'} = $ver;
	$config{'dhcpd_size'} = $st[7];
	$config{'dhcpd_mtime'} = $st[9];
	&write_file("$module_config_directory/config", \%config);
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("dhcpd", "man", "doc", "howto", "google"),
	undef, undef, &text('index_version', $config{'dhcpd_version'}));

# Create lookup type HTML
# XXX change text, add to lookup_*
$match = "<select name=match>\n";
$match .= "<option value=0 checked>$text{'index_match0'}\n";
$match .= "<option value=1>$text{'index_match1'}\n";
$match .= "<option value=2>$text{'index_match2'}\n";
$match .= "</select>\n";

# get top-level hosts
foreach $h (&find("host", $conf)) {
	push(@host, $h);
	}
foreach $g (&find("group", $conf)) {
	push(@group, $g);
	foreach $h (&find("host", $g->{'members'})) {
		push(@host, $h);
		$group{$h} = $g->{'index'};
		$par{$h} = $g;
		push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
		}
	}

# get subnets and shared nets, and the hosts and groups within them
@subn = &find("subnet", $conf);
foreach $u (@subn) {
	$maxsubn = $maxsubn > $u->{'index'} ? $maxsubn : $u->{'index'};
	foreach $h (&find("host", $u->{'members'})) {
		$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
		$subnet{$h} = $u->{'index'};
		$par{$h} = $u;
		push(@host, $h);
		}
	foreach $g (&find("group", $u->{'members'})) {
		$maxgroup = $maxgroup > $g->{'index'} ? $maxgroup : $g->{'index'};
		$subnet{$g} = $u->{'index'};
		$par{$g} = $u;
		push(@group, $g);
		foreach $h (&find("host", $g->{'members'})) {
			$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
			$subnet{$h} = $u->{'index'};
			$group{$h} = $g->{'index'};
			$par{$h} = $g;
			push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
			push(@host, $h);
			}
		}
	}
@shan = &find("shared-network", $conf);
foreach $s (@shan) {
	$maxshar = $maxshar > $s->{'index'} ? $maxshar : $s->{'index'};
	foreach $h (&find("host", $s->{'members'})) {
		$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
		$shared{$h} = $s->{'index'};
		$par{$h} = $s;
		push(@host, $h);
		}
	foreach $g (&find("group", $s->{'members'})) {
		$maxgroup = $maxgroup > $g->{'index'} ? $maxgroup : $g->{'index'};
		$shared{$g} = $s->{'index'};
		$par{$g} = $s;
		push(@group, $g);
		foreach $h (&find("host", $g->{'members'})) {
			$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
			$group{$h} = $g->{'index'};
			$shared{$h} = $s->{'index'};
			$par{$h} = $g;
			push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
			push(@host, $h);
			}
		}
	foreach $u (&find("subnet", $s->{'members'})) {
		$maxsubn = $maxsubn > $u->{'index'} ? $maxsubn : $u->{'index'};
		$par{$u} = $s;
		push(@subn, $u);
		$shared{$u} = $s->{'index'};
		foreach $h (&find("host", $u->{'members'})) {
			$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
			$subnet{$h} = $u->{'index'};
			$shared{$h} = $s->{'index'};
			$par{$h} = $u;
			push(@host, $h);
			}
		foreach $g (&find("group", $u->{'members'})) {
			$maxgroup = $maxgroup > $g->{'index'} ? $maxgroup : $g->{'index'};
			$subnet{$g} = $u->{'index'};
			$shared{$g} = $s->{'index'};
			$par{$g} = $u;
			push(@group, $g);
			foreach $h (&find("host", $g->{'members'})) {
				$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
				$subnet{$h} = $u->{'index'};
				$group{$h} = $g->{'index'};
				$shared{$h} = $s->{'index'};
				$par{$h} = $g;
				push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
				push(@host, $h);
				}
			}
		}
	}
foreach $s (@shan) {
	$s->{'order'} = (1 + $s->{'index'}) * (2 + $maxsubn);
	}
foreach $s (@subn) {
	$s->{'order'} = (defined($shared{$s}) ? (1 + $shared{$s}) * (2 + $maxsubn) : 0)
			+ 1 + $s->{'index'};
	}
if ($norder == 0) {
	@subn = (@subn, @shan);
	}
elsif ($norder == 1) {
	@subn = (@subn, @shan);
	@subn = sort { $a->{'order'} <=> $b->{'order'} } @subn;
	}
elsif ($norder == 2) {
	@subn = sort { $a->{'values'}->[0] <=> $b->{'values'}->[0] } @subn;
	@shan = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @shan;
	@subn = (@subn, @shan);
	}

# display subnets and shared nets
foreach $u (@subn) {
	local $can_view = &can('r', \%access, $u);
	next if !$can_view && $access{'hide'};
	local ($l, $t, $i);
	if ($u->{'name'} eq "subnet") {
		push(@ulinks, $l = $can_view ? 
			"edit_subnet.cgi?idx=$u->{'index'}".
			($shared{$u} ne "" ? "&sidx=$shared{$u}" : "") :
			undef);
		push(@uicons, $i = "images/subnet.gif");
		}
	else {
		push(@slinks, $l = $can_view ?
			"edit_shared.cgi?idx=$u->{'index'}" : undef);
		push(@sicons, $i = "images/shared.gif");
		}
	if ($config{'desc_name'} && $u->{'comment'}) {
		push(@utitles, $t = &html_escape($u->{'comment'}));
		}
	else {
		push(@utitles, $t = &html_escape($u->{'values'}->[0]));
		}
	push(@uslinks, $l);	# so that ordering is preserved
	push(@ustitles, $t);
	push(@usicons, $i);
	}
if ($access{'r_sub'} || $access{'c_sub'} || $access{'r_sha'} || $access{'c_sha'}) {
	print "<h3>$text{'index_subtitle'}</h3>\n";
	$sp = "";
	if (@ulinks < $display_max && @slinks < $display_max) {
		@links = @uslinks;
		@titles = @ustitles;
		@icons = @usicons;
		}
	elsif (@ulinks < $display_max) {
		@links = @ulinks;
		@titles = @utitles;
		@icons = @uicons;
		}
	elsif (@slinks < $display_max) {
		@links = @slinks;
		@titles = @stitles;
		@icons = @sicons;
		}
	if (@links) {
		# Show table of subnets and shared nets
		&index_links($norder, "n", 3, $text{'index_ndisplay'},
			"horder=$horder");
		print "<br><a href='edit_subnet.cgi?new=1'>",
		      "$text{'index_addsub'}</a>&nbsp;&nbsp;\n"
			if $access{'c_sub'};
		print "<a href='edit_shared.cgi?new=1'>",
		      "$text{'index_addnet'}</a><br>\n"
			if $access{'c_sha'};
		if ($config{'hostnet_list'} == 0) {
			&icons_table(\@links, \@titles, \@icons, $nocols);
			}
		else {
			&net_table(\@subn, 0, scalar(@subn), \@links, \@titles);
			}
		}
	elsif (!@ulinks && !@slinks) {
		# No subnets or shared nets
		print "$text{'index_nosubdef'} <p>\n";
		}

	print "<table>\n";
	if (@ulinks >= $display_max) {
		# Could not show all subnets, so show lookup form
		print "<form action=lookup_subnet.cgi>\n";
		print "<tr> <td><b>$text{'index_subtoomany'}</b></td>\n";
		print "<td><input type=submit value='$text{'index_sublook2'}'></td>\n";
		print "<td>$matches</td>\n";
		print "<td><input name=subnet size=30></td></tr> </form>\n";
		}
	if (@slinks >= $display_max) {
		# Could not show all shared nets, so show lookup form
		print "<form action=lookup_shared.cgi>\n";
		print "<tr> <td><b>$text{'index_shatoomany'}</b></td>\n";
		print "<td><input type=submit value='$text{'index_shalook2'}'></td>\n";
		print "<td>$matches</td>\n";
		print "<td><input name=shared size=30></td></tr> </form>\n";
		}
	print "</tr></table><p>\n";
	}
print "<a href='edit_subnet.cgi?new=1'>$text{'index_addsub'}</a>&nbsp;&nbsp;\n"
	if $access{'c_sub'};
print "<a href='edit_shared.cgi?new=1'>$text{'index_addnet'}</a><p>\n"
	if $access{'c_sha'};
print "<hr>\n";

foreach $g (@group) {
	$parent = (defined($subnet{$g}) ? 1 + $subnet{$g} : 0) +
		  (defined($shared{$g}) ? (1 + $shared{$g}) * (2 + $maxsubn) : 0);
	$g->{'order'} = $parent + (1 + $g->{'index'}) / (2 + $maxgroup);
	}
foreach $h (@host) {
	$parent = (defined($group{$h}) ? (1 + $group{$h}) / (2 + $maxgroup) : 0) +
		  (defined($subnet{$h}) ? 1 + $subnet{$h} : 0) +
		  (defined($shared{$h}) ? (1 + $shared{$h}) * (2 + $maxsubn) : 0);
	$h->{'order'} = $parent + (1 + $h->{'index'}) /
			((1 + @group) * (2 + $maxhost));
	}
if ($horder == 0) {
	@host = (@host, @group);
	}
elsif ($horder == 1) {
	@host = (@host, @group);
	@host = sort { $a->{'order'} <=> $b->{'order'} } @host;
	}
elsif ($horder == 2) {
	@host = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @host;
	@host = (@host, @group);
	}
elsif ($horder == 3) {
	@host = sort { &hardware($a) cmp &hardware($b) } @host;
	@host = (@host, @group);
	}
elsif ($horder == 4) {
	@host = sort { &ipaddress($a) cmp &ipaddress($b) } @host;
	@host = (@host, @group);
	}

# display hosts
foreach $h (@host) {
	local $can_view = &can('r', \%access, $h);
	next if !$can_view && $access{'hide'};
	if ($h->{'name'} eq 'host') {
		# Add icon for a host
		push(@hlinks, $l = $can_view ?
			"edit_host.cgi?idx=$h->{'index'}".
			(defined($group{$h}) ? "&gidx=$group{$h}" : "").
			(defined($subnet{$h}) ? "&uidx=$subnet{$h}" : "").
			(defined($shared{$h}) ? "&sidx=$shared{$h}" : "") :
			undef);
		if ($config{'desc_name'} && $h->{'comment'}) {
			push(@htitles, &html_escape($h->{'comment'}));
			}
		else {
			push(@htitles, &html_escape($h->{'values'}->[0]));
			}
		if ($config{'show_ip'}) {
			local $fixed = &find("fixed-address", $h->{'members'});
			$htitles[$#htitles] .= "<br>$fixed->{'value'}"
				if ($fixed);
			}
		if ($config{'show_mac'}) {
			local $hard = &find("hardware", $h->{'members'});
			$htitles[$#htitles] .= "<br>$hard->{'values'}->[1]"
				if ($hard);
			}
		$t = $htitles[$#htitles];
		push(@hicons, $i = "images/host.gif");
		}
	else {
		# Add icon for a group
		push(@glinks, $l = $can_view ?
			"edit_group.cgi?idx=$h->{'index'}".
			(defined($subnet{$h}) ? "&uidx=$subnet{$h}" : "").
			(defined($shared{$h}) ? "&sidx=$shared{$h}" : "") :
			undef);
		$gm = @{$h->{'hosts'}};
		if ($config{'desc_name'} && $h->{'comment'}) {
			push(@htitles, $t = &html_escape($h->{'comment'}));
			}
		else {
			push(@gtitles, $t = &html_escape(&group_name($gm, $h)));
			}
		push(@gicons, $i = "images/group.gif");
		}
	push(@hglinks, $l);
	push(@hgtitles, $t);
	push(@hgicons, $i);
	}
if ($access{'r_hst'} || $access{'c_hst'} ||
    $access{'r_grp'} || $access{'c_grp'}) {
	print "<h3>$text{'index_hst'}</h3>\n";
	$sp = "";
	if (@hlinks < $display_max && @glinks < $display_max) {
		@links = @hglinks;
		@titles = @hgtitles;
		@icons = @hgicons;
		}
	elsif (@hlinks < $display_max) {
		@links = @hlinks;
		@titles = @htitles;
		@icons = @hicons;
		}
	elsif (@glinks < $display_max) {
		@links = @glinks;
		@titles = @gtitles;
		@icons = @gicons;
		}
	if (@links) {
		# Some hosts or groups to show
		&index_links($horder, "h", 5, $text{'index_hdisplay'},
			"norder=$norder");
		print "<br><a href='edit_host.cgi?new=1'>",
		      "$text{'index_addhst'}</a>&nbsp;&nbsp;\n"
			if $access{'c_hst'};
		print "<a href='edit_group.cgi?new=1'>",
		      "$text{'index_addhstg'}</a><br>\n"
			if $access{'c_grp'};
		if ($config{'hostnet_list'} == 0) {
			&icons_table(\@links, \@titles, \@icons, $nocols);
			}
		else {
			&host_table(\@host, 0, scalar(@host), \@links, \@titles);
			}
		}
	elsif (!@hlinks && !@glinks) {
		# None to show at all
		print "$text{'index_nohst'} <p>\n";
		}

	print "<table>\n";
	if (@hlinks >= $display_max) {
		# Could not show all hosts, so show lookup form
		print "<form action=lookup_host.cgi>\n";
		print "<tr> <td><b>$text{'index_hsttoomany'}</b></td>\n";
		print "<td><input type=submit value='$text{'index_hstlook2'}'></td>\n";
		print "<td>$matches</td>\n";
		print "<td><input name=host size=30></td></tr> </form>\n";
		}
	if (@glinks >= $display_max) {
		# Could not show all groups, so show lookup form
		print "<form action=lookup_group.cgi>\n";
		print "<tr> <td><b>$text{'index_grptoomany'}</b></td>\n";
		print "<td><input type=submit value='$text{'index_grplook2'}'></td>\n";
		print "<td>$matches</td>\n";
		print "<td><input name=group size=30></td></tr> </form>\n";
		}
	print "</tr></table><p>\n";
	}
print "<a href='edit_host.cgi?new=1'>$text{'index_addhst'}</a>&nbsp;&nbsp;\n"
	if $access{'c_hst'};
print "<a href='edit_group.cgi?new=1'>$text{'index_addhstg'}</a><p>\n"
	if $access{'c_grp'};
print "<hr>\n";

print "<table>\n";
if ($access{'global'}) {
	print "<form action=edit_options.cgi>\n";
	print "<input type=hidden name=global value=1>\n";
	print "<tr> <td><input type=submit value=\"$text{'index_buttego'}\"></td>\n";
	print "<td>$text{'index_ego'} \n";
	print "</td> </tr>\n";
	print "</form>\n";
	}
if (!$access{'noconfig'}) {
	print "<!--form action=edit_iface.cgi>\n";
	print "<tr> <td><input type=submit value=\"$text{'index_buttiface'}\"></td>\n";
	print "<td>$text{'index_iface'} \n";
	print "</td> </tr>\n";
	print "</form-->\n";
	}
if ($access{'r_leases'}) {
	print "<form action=list_leases.cgi>\n";
	print "<tr> <td><input type=submit value=\"$text{'index_buttlal'}\"></td>\n";
	print "<td>$text{'index_lal'} \n";
	print "</td> </tr>\n";
	print "</form>\n";
	}
if ($access{'apply'}) {
	$pid = &check_pid_file(&get_pid_file());
	if ($pid) {
		print "<form action=restart.cgi>\n";
		print "<input type=hidden name=pid value=$pid>\n";
		print "<tr> <td><input type=submit value=\"$text{'index_buttapply'}\"></td>\n";
		print "<td>$text{'index_apply'} \n";
		print "</td></tr>\n";
		print "</form>\n";
		}
	else {
		print "<form action=start.cgi>\n";
		print "<tr> <td><input type=submit value=\"$text{'index_buttstart'}\"></td>\n";
		print "<td>$text{'index_start'} \n";
		print "</td> </tr>\n";
		print "</form>\n";
		}
	}

#	-- Wapsol code
if ($in{action} eq 'Stop Server')
{
#	system ("/etc/init.d/dhcp3-server stop");
	system ("/usr/bin/killall dhcpd");
	# print "OK, ready to stop"; return; 
	set_property("START_DHCP", "0");
	print "<tr><td>&nbsp;</td><td><font color=red>DHCP Stopped</font></td></tr>";
}
print "<form action=index.cgi method=post>";
print "<tr><td><input type=submit name=action value='Stop Server'></td><td>Stops DHCP server if it is running</td></tr>";
print "</form>";
#	-- end Wapsol code

print "</table>\n";

&ui_print_footer("/", $text{'index_return'});

# Returns canonized hardware address.
sub hardware {
	local ($hconf, $addr);
	$hconf = $_[0]->{'members'} ? &find("hardware", $_[0]->{'members'}) : undef;
	if ($hconf) {
		$addr = uc($hconf->{'values'}->[1]);
		$addr =~ s/(^|\:)([0-9A-F])(?=$|\:)/$1\x30$2/g;
	}
	return $hconf ? $addr : undef;
}

# Returns ip address for sorting on
sub ipaddress
{
return undef if (!$_[0]->{'members'});
local $iconf = &find("fixed-address", $_[0]->{'members'});
return undef if (!$iconf);
return sprintf "%3.3d.%3.3d.%3.3d.%3.3d",
		split(/\./, $iconf->{'values'}->[0]);
}

sub fixedaddr {
	local ($fixed, $addr);
	$fixed = &find("fixed-address", $_[0]->{'members'});
	$addr = join(" ", grep { $_ ne "," } @{$fixed->{'values'}});
	$addr =~ s/, / /g;
	return $addr;
}

sub netmask {
	return $_[0]->{'values'}->[2];
}

# index_links(current, name, max, txt, ref)
sub index_links
{
local (%linkname, $l);
print "<table><tr><td valign=top><b>$_[3] </b>&nbsp;&nbsp;</td>\n";
print "<td>";
for ($l = 0; $l < $_[2]; $l++) {
	if ($l ne $_[0]) {
		print "<a href=?$_[1]order=$l\&$_[4]>";
		}
	else {
		print "<b>";
		}
	print $text{"index_$_[1]order$l"};
	if ($l ne $_[0]) {
		print "</a>";
		}
	else {
		print "</b>";
		}
	print "&nbsp;\n";
	}
print "</td></table>\n";
open(INDEX, "> $module_config_directory/$_[1]index.".$remote_user);
print INDEX "$_[0]\n";
close(INDEX);
}

sub host_table
{
local ($i, $h, $parent);
print "<table border width=95%>\n";
print "<tr $tb> <td><b>", $text{'index_hostgroup'}, "</b></td> ",
      "<td><b>", $text{'index_parent'}, "</b></td> ",
      "<td><b>", $text{'index_hardware'}, "</b></td> ",
      "<td><b>", $text{'index_nameip'}, "</b></td> </tr>\n";
for ($i = $_[1]; $i < $_[2]; $i++) {
	print "<tr $cb> <td>\n";
	$h = $_[0]->[$i];
	if ($h->{'name'} eq 'host') {
		print $sp;
		}
	else {
		print $text{'index_group'}, " ";
		$sp = "\&nbsp;\&nbsp;";
		}
	if ($_[3]->[$i]) {
		print "<a href=$_[3]->[$i]>", $_[4]->[$i], "</a> </td>\n";
		}
	else {
		print $_[4]->[$i], "</td>\n";
		}

	if ($par{$h}->{'name'} eq "group") {		
	    $par_type = $text{'index_togroup'};
	    $parent = &group_name(scalar @{$par{$h}->{'hosts'}});
	}
	elsif ($par{$h}->{'name'} eq "subnet") {
	    $par_type = $text{'index_tosubnet'};
	    $parent = $par{$h}->{'values'}->[0];
	}
	elsif ($par{$h}->{'name'} eq "shared-network") {
	    $par_type = $text{'index_toshared'};
	    $parent = $par{$h}->{'values'}->[0];
	}

	if ($config{'desc_name'} && $par{$h}->{'comment'}) {
	    $parent = $par{$h}->{'comment'};
	}
	print "<td> $par_type:  $parent \&nbsp;</td>\n";
	print "<td>", $_[3]->[$i] ? &hardware($h) : "", "\&nbsp;</td>\n";
	print "<td>", $_[3]->[$i] ? &fixedaddr($h) : "", "\&nbsp;</td>\n";
	print "</tr>\n";
	}
print "</table>\n"
}

#&net_table(\@subn, 0, scalar(@subn), \@links, \@titles);
sub net_table
{
local ($i, $n);
print "<table border width=95%>\n";
print "<tr $tb> <td><b>", $text{'index_net'}, "</b></td> ",
      "<td><b>", $text{'index_netmask'}, "</b></td> ",
      "<td><b>", $text{'index_desc'}, "</b></td> ",
      "<td><b>", $text{'index_parent'}, "</b></td> </tr>\n";
for ($i = $_[1]; $i < $_[2]; $i++) {
	print "<tr $cb> <td>\n";
	$n = $_[0]->[$i];
	if ($n->{'name'} eq 'subnet') {
		print $sp;
		}
	else {
		$sp = "\&nbsp;\&nbsp;";
		}
	if ($_[3]->[$i]) {
		print "<a href=$_[3]->[$i]>", $_[4]->[$i], "</a> </td>\n";
		}
	else {
		print $_[4]->[$i], "</td>\n";
		}
	print "<td>", $_[3]->[$i] ? &netmask($n) : "", "\&nbsp;</td>\n";
	print "<td>",  $n->{'comment'} ? $n->{'comment'} : "", "\&nbsp;</td>\n";
	print "<td>", $par{$n} ? 
		"$text{'index_toshared'} $par{$n}->{'values'}->[0]" : "",
		"\&nbsp;</td>\n";
	print "</tr>\n";
	}
print "</table>\n"
}
