# servers-lib.pl
# Common functions for managing servers

do '../web-lib.pl';
&init_config();
require '../ui-lib.pl';
%access = &get_module_acl();

sub list_servers
{
local ($f, @rv);
opendir(DIR, $module_config_directory);
while($f = readdir(DIR)) {
	if ($f =~ /^(\d+)\.serv$/) {
		push(@rv, &get_server($1));
		}
	}
closedir(DIR);
return @rv;
}

# get_server(id)
sub get_server
{
local $serv;
$serv->{'id'} = $_[0];
&read_file("$module_config_directory/$_[0].serv", $serv) || return undef;
return $serv;
}

# save_server(&server)
sub save_server
{
&lock_file("$module_config_directory/$_[0]->{'id'}.serv");
&write_file("$module_config_directory/$_[0]->{'id'}.serv", $_[0]);
chmod(0600, "$module_config_directory/$_[0]->{'id'}.serv");
&unlock_file("$module_config_directory/$_[0]->{'id'}.serv");
}

# delete_server(id)
sub delete_server
{
&lock_file("$module_config_directory/$_[0].serv");
unlink("$module_config_directory/$_[0].serv");
&unlock_file("$module_config_directory/$_[0].serv");
}

# can_use_server(&server)
sub can_use_server
{
return 1 if ($access{'servers'} eq '*');
foreach $s (split(/\s+/, $access{'servers'})) {
	return 1 if ($_[0]->{'host'} eq $s ||
		     $_[0]->{'id'} eq $s);
	}
return 0;
}

# list_all_groups([&servers])
# Returns a list of all webmin and MSC groups and their members
sub list_all_groups
{
local (@rv, %gmap, $s, $f, $gn);

# Add webmin servers groups
foreach $s ($_[0] ? @{$_[0]} : &list_servers()) {
	foreach $gn (split(/\t+/, $s->{'group'})) {
		local $grp = $gmap{$gn};
		if (!$grp) {
			$gmap{$s->{'group'}} = $grp = { 'name' => $gn,
							'type' => 0 };
			push(@rv, $grp);
			}
		push(@{$grp->{'members'}}, $s->{'host'});
		}
	}

# Add MSC cluster groups
opendir(DIR, $config{'groups_dir'});
foreach $f (readdir(DIR)) {
	next if ($f eq '.' || $f eq '..');
	local $grp = $gmap{$f};
	if (!$grp) {
		$gmap{$f} = $grp = { 'name' => $f, 'type' => 1 };
		push(@rv, $grp);
		}
	open(GROUP, "$config{'groups_dir'}/$f");
	while(<GROUP>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/(\S*)\[(\d)-(\d+)\](\S*)/) {
			# Expands to multiple hosts
			push(@{$grp->{'members'}}, map { $1.$_.$4 } ($2 .. $3));
			}
		elsif (/(\S+)/) {
			push(@{$grp->{'members'}}, $1);
			}
		}
	close(GROUP);
	}
closedir(DIR);

# Fix up MSC groups that include other groups
while(1) {
	local ($grp, $any);
	foreach $grp (@rv) {
		local @mems;
		foreach $m (@{$grp->{'members'}}) {
			if ($m =~ /^:(.*)$/) {
				push(@mems, @{$gmap{$1}->{'members'}});
				$any++;
				}
			else {
				push(@mems, $m);
				}
			}
		$grp->{'members'} = \@mems;
		}
	last if (!$any);
	}

return @rv;
}

# logged_in(&serv)
sub logged_in
{
local $id = $_[0]->{'id'};
if ($ENV{'HTTP_COOKIE'} =~ /$id=([A-Za-z0-9=]+)/) {
	return split(/:/, &decode_base64("$1"));
	}
else {
	return ();
	}
}

@server_types = ( [ 'caldera', 'OpenLinux', 'open-linux' ],
		  [ 'redhat', 'Redhat Linux', 'redhat-linux' ],
		  [ 'fedora', 'Fedora Linux', undef, 'Fedora' ],
		  [ 'suse', 'SuSE Linux', 'suse-linux' ],
		  [ 'debian', 'Debian Linux', 'debian-linux' ],
		  [ 'mandrake', 'Mandrake Linux', 'mandrake-linux' ],
		  [ 'msc', 'MSC.Linux', 'msc-linux' ],
		  [ 'cobalt', 'Cobalt Linux', 'cobalt-linux' ],
		  [ 'linux', 'Linux', '.*-linux' ],
		  [ 'freebsd', 'FreeBSD', 'freebsd' ],
		  [ 'solaris', 'Solaris', 'solaris' ],
		  [ 'hpux', 'HP/UX', 'hpux' ],
		  [ 'sco', 'SCO', '(openserver|unixware)' ],
		  [ 'mac', 'Macintosh', 'macos' ],
		  [ 'irix', 'IRIX', 'irix' ],
		  [ 'unknown', $text{'lib_other'} ] );

# this_server()
# Returns a fake servers-list entry for this server
sub this_server
{
local $type = 'unknown';
foreach $s (@server_types) {
	if ($s->[2] && $gconfig{'os_type'} =~ /^$s->[2]$/ ||
	    $s->[3] && $gconfig{'real_os_type'} =~ /$s->[3]/) {
		$type = $s->[0];
		last;
		}
	}
return { 'id' => 0, 'desc' => $text{'this_server'}, 'type' => $type };
}

# get_my_address()
# Returns the system's IP address, or undef
sub get_my_address
{
local $myip;
if (&foreign_check("net")) {
	# Try to get ethernet interface
	&foreign_require("net", "net-lib.pl");
	local @act = &net::active_interfaces();
	local ($iface) = grep { &net::iface_type($_->{'fullname'}) =~ /ether/i }
			      @act;
	$iface = $act[0] if (!$iface);
	return $iface->{'address'} if ($iface);
	}
$myip = &to_ipaddress(&get_system_hostname());
if ($myip) {
	# Can resolve hostname .. use that
	return $myip;
	}
return undef;
}

# address_to_broadcast(address, net-mode)
sub address_to_broadcast
{
local $end = $_[1] ? "0" : "255";
local @ip = split(/\./, $_[0]);
return $ip[0] >= 192 ? "$ip[0].$ip[1].$ip[2].$end" :
       $ip[0] >= 128 ? "$ip[0].$ip[1].$end.$end" :
		       "$ip[0].$end.$end.$end";
}

1;

