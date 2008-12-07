# united-linux-lib.pl
# Networking functions for united linux

$net_scripts_dir = "/etc/sysconfig/network";
$routes_config = "/etc/sysconfig/network/routes";
$sysctl_config = "/etc/sysconfig/sysctl";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local(@rv, $f);
opendir(CONF, $net_scripts_dir);
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-([a-z0-9:\.]+)$/);
	local (%conf, $b);
	$b->{'fullname'} = $1;
	&read_env_file("$net_scripts_dir/$f", \%conf);
	if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
		$b->{'name'} = $1;
		$b->{'virtual'} = $2;
		}
	else { $b->{'name'} = $b->{'fullname'}; }
	$b->{'up'} = ($conf{'STARTMODE'} eq 'onboot');
	local $pfx;
	if ($conf{'IPADDR'} =~ /^(\S+)\/(\d+)$/) {
		$b->{'address'} = $1;
		$pfx = $2;
		}
	else {
		$b->{'address'} = $conf{'IPADDR'};
		}
	$pfx = $conf{'PREFIXLEN'} if (!$pfx);
	if ($pfx) {
		$b->{'netmask'} = &prefix_to_mask($pfx);
		}
	else {
		$b->{'netmask'} = $conf{'NETMASK'};
		}
	$b->{'broadcast'} = $conf{'BROADCAST'};
	$b->{'dhcp'} = ($conf{'BOOTPROTO'} eq 'dhcp');
	$b->{'edit'} = ($b->{'name'} !~ /^ppp|irlan/);
	$b->{'index'} = scalar(@rv);
	$b->{'file'} = "$net_scripts_dir/$f";
	push(@rv, $b);
	}
closedir(CONF);
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local(%conf);
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&lock_file("$net_scripts_dir/ifcfg-$name");
&read_env_file("$net_scripts_dir/ifcfg-$name", \%conf);
$conf{'IPADDR'} = $_[0]->{'address'};
local($ip1, $ip2, $ip3, $ip4) = split(/\./, $_[0]->{'address'});
$conf{'NETMASK'} = $_[0]->{'netmask'};
local($nm1, $nm2, $nm3, $nm4) = split(/\./, $_[0]->{'netmask'});
if ($_[0]->{'address'} && $_[0]->{'netmask'}) {
	$conf{'NETWORK'} = sprintf "%d.%d.%d.%d",
				($ip1 & int($nm1))&0xff,
				($ip2 & int($nm2))&0xff,
				($ip3 & int($nm3))&0xff,
				($ip4 & int($nm4))&0xff;
	}
else {
	$conf{'NETWORK'} = '';
	}
delete($conf{'PREFIXLEN'});
$conf{'BROADCAST'} = $_[0]->{'broadcast'};
$conf{'STARTMODE'} = $_[0]->{'up'} ? "onboot" :
		     $conf{'STARTMODE'} eq "onboot" ? "manual" :
						      $conf{'STARTMODE'};
$conf{'BOOTPROTO'} = $_[0]->{'dhcp'} ? "dhcp" : "static";
$conf{'UNIQUE'} = time();
&write_env_file("$net_scripts_dir/ifcfg-$name", \%conf);
&unlock_file("$net_scripts_dir/ifcfg-$name");
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&lock_file("$net_scripts_dir/ifcfg-$name");
unlink("$net_scripts_dir/ifcfg-$name");
&unlock_file("$net_scripts_dir/ifcfg-$name");
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] ne "mtu" && $_[0] ne "bootp";
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return &check_ipaddress($_[0]);
}

# get_dns_config()
# Returns a hashtable containing keys nameserver, domain, search & order
sub get_dns_config
{
local $dns;
open(RESOLV, "/etc/resolv.conf");
while(<RESOLV>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/nameserver\s+(.*)/) {
		push(@{$dns->{'nameserver'}}, split(/\s+/, $1));
		}
	elsif (/domain\s+(\S+)/) {
		$dns->{'domain'} = [ $1 ];
		}
	elsif (/search\s+(.*)/) {
		$dns->{'domain'} = [ split(/\s+/, $1) ];
		}
	}
close(RESOLV);
open(SWITCH, "/etc/nsswitch.conf");
while(<SWITCH>) {
	s/\r|\n//g;
	if (/^\s*hosts:\s+(.*)/) {
		$dns->{'order'} = $1;
		}
	}
close(SWITCH);
$dns->{'files'} = [ "/etc/resolv.conf", "/etc/nsswitch.conf" ];
return $dns;
}

# save_dns_config(&config)
# Writes out the resolv.conf and nsswitch.conf files
sub save_dns_config
{
&lock_file("/etc/resolv.conf");
open(RESOLV, "/etc/resolv.conf");
local @resolv = <RESOLV>;
close(RESOLV);
open(RESOLV, ">/etc/resolv.conf");
foreach (@{$_[0]->{'nameserver'}}) {
	print RESOLV "nameserver $_\n";
	}
if ($_[0]->{'domain'}) {
	if ($_[0]->{'domain'}->[1]) {
		print RESOLV "search ",join(" ", @{$_[0]->{'domain'}}),"\n";
		}
	else {
		print RESOLV "domain $_[0]->{'domain'}->[0]\n";
		}
	}
foreach (@resolv) {
	print RESOLV $_ if (!/^\s*(nameserver|domain|search)\s+/);
	}
close(RESOLV);
&unlock_file("/etc/resolv.conf");

&lock_file("/etc/nsswitch.conf");
open(SWITCH, "/etc/nsswitch.conf");
local @switch = <SWITCH>;
close(SWITCH);
open(SWITCH, ">/etc/nsswitch.conf");
foreach (@switch) {
	if (/^\s*hosts:\s+/) {
		print SWITCH "hosts:\t$_[0]->{'order'}\n";
		}
	else { print SWITCH $_; }
	}
close(SWITCH);
&unlock_file("/etc/nsswitch.conf");
}

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
if ($_[0]->{'order'} =~ /\[/) {
	# Using a complex resolve list
	return "<input name=order size=45 value=\"$_[0]->{'order'}\">\n";
	}
else {
	# Can select by menus
	local @o = split(/\s+/, $_[0]->{'order'});
	@o = map { s/nis\+/nisplus/; s/yp/nis/; $_; } @o;
	local ($rv, $i, $j);
	local @srcs = ( "", "files", "dns", "nis", "nisplus", "db" );
	local @srcn = ( "", "Hosts", "DNS", "NIS", "NIS+", "DB" );
	for($i=1; $i<@srcs; $i++) {
		local $ii = $i-1;
		$rv .= "<select name=order_$ii>\n";
		for($j=0; $j<@srcs; $j++) {
			$rv .= sprintf "<option value=\"%s\" %s>%s\n",
					$srcs[$j],
					$o[$ii] eq $srcs[$j] ? "selected" : "",
					$srcn[$j] ? $srcn[$j] : "&nbsp;";
			}
		$rv .= "</select>\n";
		}
	return $rv;
	}
}

# parse_order(&dns)
# Parses the form created by order_input()
sub parse_order
{
if (defined($in{'order'})) {
	$in{'order'} =~ /\S/ || &error($text{'dns_eorder'});
	$_[0]->{'order'} = $in{'order'};
	}
else {
	local($i, @order);
	for($i=0; defined($in{"order_$i"}); $i++) {
		push(@order, $in{"order_$i"}) if ($in{"order_$i"});
		}
	$_[0]->{'order'} = join(" ", @order);
	}
}

# get_hostname()
sub get_hostname
{
return &get_system_hostname(1);
}

# save_hostname(name)
sub save_hostname
{
local %conf;
&system_logged("hostname $_[0] >/dev/null 2>&1");
&lock_file("/etc/HOSTNAME");
open(HOST, ">/etc/HOSTNAME");
print HOST $_[0],"\n";
close(HOST);
&unlock_file("/etc/HOSTNAME");
&lock_file($network_config);
&read_env_file($network_config, \%conf);
$conf{'HOSTNAME'} = $_[0];
&write_env_file($network_config, \%conf);
&unlock_file($network_config);
}

# get_domainname()
sub get_domainname
{
local $d = `domainname`;
chop($d);
return $d eq "(none)" ? "" : $d;
}

# save_domainname(domain)
sub save_domainname
{
local %conf;
system("domainname \"$_[0]\" >/dev/null 2>&1");
&read_env_file($network_config, \%conf);
if ($_[0]) {
	$conf{'NISDOMAIN'} = $_[0];
	}
else {
	delete($conf{'NISDOMAIN'});
	}
&write_env_file($network_config, \%conf);
}

sub routing_config_files
{
return ( $routes_config, $sysctl_config );
}

sub routing_input
{
local (@routes, $i);
open(ROUTES, $routes_config);
while(<ROUTES>) {
	s/#.*$//;
	s/\r|\n//g;
	local @r = map { $_ eq '-' ? undef : $_ } split(/\s+/, $_);
	push(@routes, \@r) if (@r);
	}
close(ROUTES);

# show default router and device
local ($def) = grep { $_->[0] eq "default" } @routes;
print "<tr> <td><b>$text{'routes_default'}</b></td> <td>\n";
printf "<input type=radio name=gateway_def value=1 %s> $text{'routes_none'}\n",
	$def->[1] ? "" : "checked";
printf "<input type=radio name=gateway_def value=0 %s>\n",
	$def->[1] ? "checked" : "";
printf "<input name=gateway size=15 value=\"%s\"></td> </tr>\n",
	$def->[1];

print "<tr> <td><b>$text{'routes_device2'}</b></td> <td>\n";
printf "<input type=radio name=gatewaydev_def value=1 %s> $text{'routes_none'}\n",
	$def->[3] ? "" : "checked";
printf "<input type=radio name=gatewaydev_def value=0 %s>\n",
	$def->[3] ? "checked" : "";
printf "<input name=gatewaydev size=6 value=\"%s\"></td> </tr>\n",
	$def->[3];

&read_env_file($sysctl_config, \%sysctl);
print "<tr> <td><b>$text{'routes_forward'}</b></td> <td>\n";
printf "<input type=radio name=forward value=1 %s> $text{'yes'}\n",
	$sysctl{'IP_FORWARD'} eq 'yes' ? "checked" : "";
printf "<input type=radio name=forward value=0 %s> $text{'no'}</td> </tr>\n",
	$sysctl{'IP_FORWARD'} eq 'yes' ? "" : "checked";

# show static network routes
print "<tr> <td valign=top><b>$text{'routes_static'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
      "<td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> ",
      "<td><b>$text{'routes_gateway'}</b></td> ",
      "<td><b>$text{'routes_type'}</b></td> </tr>\n";
local ($r, $i = 0);
foreach $r (@routes, [ ]) {
	next if ($r eq $def);
	print "<tr $cb>\n";
	print "<td><input name=dev_$i size=6 value='$r->[3]'></td>\n";
	print "<td><input name=net_$i size=15 value='$r->[0]'></td>\n";
	print "<td><input name=netmask_$i size=15 value='$r->[2]'></td>\n";
	print "<td><input name=gw_$i size=15 value='$r->[1]'></td>\n";
	print "<td><input name=type_$i size=10 value='$r->[4]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
}

sub parse_routing
{
# Parse route inputs
local (@routes, $r, $i);
if (!$in{'gateway_def'}) {
	gethostbyname($in{'gateway'}) ||
		&error(&text('routes_edefault', $in{'gateway'}));
	local @def = ( "default", $in{'gateway'}, undef, undef );
	if (!$in{'gatewaydev_def'}) {
		$in{'gatewaydev'} =~ /^\S+$/ ||
			&error(&text('routes_edevice', $in{'gatewaydev'}));
		$def[3] = $in{'gatewaydev'};
		}
	push(@routes, \@def);
	}
for($i=0; defined($in{"dev_$i"}); $i++) {
	next if (!$in{"net_$i"});
	&check_ipaddress($in{"net_$i"}) ||
		$in{"net_$i"} =~ /^(\S+)\/(\d+)$/ && &check_ipaddress($1) ||
		&error(&text('routes_enet', $in{"net_$i"}));
	$in{"dev_$i"} =~ /^\S*$/ || &error(&text('routes_edevice', $dev));
	!$in{"netmask_$i"} || &check_ipaddress($in{"netmask_$i"}) ||
		&error(&text('routes_emask', $in{"netmask_$i"}));
	!$in{"gw_$i"} || &check_ipaddress($in{"gw_$i"}) ||
		&error(&text('routes_egateway', $in{"gw_$i"}));
	$in{"type_$i"} =~ /^\S*$/ ||
		&error(&text('routes_etype', $in{"type_$i"}));
	push(@routes, [ $in{"net_$i"}, $in{"gw_$i"}, $in{"netmask_$i"},
			$in{"dev_$i"}, $in{"type_$i"} ] );
	}

# Save routes and routing option
open(ROUTES, ">$routes_config");
foreach $r (@routes) {
	print ROUTES join(" ", map { $_ eq '' ? "-" : $_ } @$r),"\n";
	}
close(ROUTES);
local $lref = &read_file_lines($sysctl_config);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^\s*IP_FORWARD\s*=/) {
		$lref->[$i] = "IP_FORWARD=".($in{'forward'} ? "yes" : "no");
		}
	}
&flush_file_lines();
}

sub os_feedback_files
{
opendir(DIR, $net_scripts_dir);
local @f = readdir(DIR);
closedir(DIR);
return ( (map { "$net_scripts_dir/$_" } grep { /^ifcfg-/ } @f),
	 $network_config, $static_route_config, "/etc/resolv.conf",
	 "/etc/nsswitch.conf", "/etc/HOSTNAME" );
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
system("(cd / ; /etc/init.d/network stop ; /etc/init.d/network start) >/dev/null 2>&1");
}

1;

