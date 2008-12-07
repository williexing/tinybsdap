# open-linux.pl
# Networking functions for openlinux

$net_scripts_dir = "/etc/sysconfig/network-scripts";
$network_config = "/etc/sysconfig/network";
$static_route_config = "/etc/sysconfig/network-scripts/ifcfg-routes";
$nis_conf = "/etc/nis.conf";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local(@rv, $f);
opendir(CONF, $net_scripts_dir);
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-(\S+)/ || $f eq 'ifcfg-routes' ||
		 $f =~ /\.sample$/);
	local (%conf, $b);
	&read_env_file("$net_scripts_dir/$f", \%conf);
	$b->{'fullname'} = $conf{'DEVICE'} ? $conf{'DEVICE'} : $1;
	if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
		$b->{'name'} = $1;
		$b->{'virtual'} = $2;
		}
	else { $b->{'name'} = $b->{'fullname'}; }
	$b->{'up'} = ($conf{'ONBOOT'} eq 'yes');
	$b->{'address'} = $conf{'IPADDR'} ? $conf{'IPADDR'} : "Automatic";
	$b->{'netmask'} = $conf{'NETMASK'} ? $conf{'NETMASK'} : "Automatic";
	$b->{'broadcast'} = $conf{'BROADCAST'} ? $conf{'BROADCAST'}
					       : "Automatic";
	$b->{'dhcp'} = $conf{'DYNAMIC'} eq 'dhcp';
	$b->{'edit'} = ($b->{'name'} !~ /^ppp|plip/);
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
$conf{'DEVICE'} = $name;
if ($_[0]->{'dhcp'}) {
	$conf{'DYNAMIC'} = 'dhcp';
	}
else {
	$conf{'IPADDR'} = $_[0]->{'address'};
	delete($conf{'DYNAMIC'});
	}
local($ip1, $ip2, $ip3, $ip4) = split(/\./, $_[0]->{'address'});
$conf{'NETMASK'} = $_[0]->{'netmask'};
local($nm1, $nm2, $nm3, $nm4) = split(/\./, $_[0]->{'netmask'});
$conf{'NETWORK'} = sprintf "%d.%d.%d.%d",
			($ip1 & int($nm1))&0xff,
			($ip2 & int($nm2))&0xff,
			($ip3 & int($nm3))&0xff,
			($ip4 & int($nm4))&0xff;
$conf{'BROADCAST'} = $_[0]->{'broadcast'};
$conf{'ONBOOT'} = $_[0]->{'up'} ? "yes" : "no";
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
return $_[0] ne "bootp" && $_[0] ne "mtu";
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
	if (/^nameserver\s+(.*)/) {
		push(@{$dns->{'nameserver'}}, split(/\s+/, $1));
		}
	elsif (/^domain\s+(\S+)/) {
		$dns->{'domain'} = [ $1 ];
		}
	elsif (/^search\s+(.*)/) {
		$dns->{'domain'} = [ split(/\s+/, $1) ];
		}
	}
close(RESOLV);
open(SWITCH, "/etc/nsswitch.conf");
while(<SWITCH>) {
	s/\r|\n//g;
	if (/hosts:\s+(.*)/) {
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
	if (/hosts:\s+/) {
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
	local @srcs = ( "", "files", "dns", "nis", "nisplus" );
	local @srcn = ( "", "Hosts", "DNS", "NIS", "NIS+" );
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
&read_file($network_config, \%conf);
$conf{'HOSTNAME'} = $_[0];
&write_file($network_config, \%conf);
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
&read_file("$network_config", \%conf);
if ($_[0]) {
	$conf{'NISDOMAIN'} = $_[0];
	}
else {
	delete($conf{'NISDOMAIN'});
	}
&write_file("$network_config", \%conf);
# XXX need to update nis.conf
}

sub routing_config_files
{
return ( $network_config,
	 map { $_->{'file'} } &boot_interfaces() );
}

sub routing_input
{
local (%conf, %ifc, $f, $gateway, $gatewaydev);
&read_file($network_config, \%conf);
local ($gateway, $gatewaydev) = &get_default_gateway();

print "<tr> <td><b>$text{'routes_default'}</b></td> <td>\n";
printf "<input type=radio name=gateway_def value=1 %s> %s\n",
	$gateway ? "" : "checked", $text{'routes_none'};
printf "<input type=radio name=gateway_def value=0 %s> %s\n",
	$gateway ? "checked" : "", $text{'routes_gateway'};
printf "<input name=gateway size=15 value=\"%s\"> %s\n",
	$gateway, $text{'routes_device'};
printf "<input name=gatewaydev size=6 value=\"%s\"></td> </tr>\n",
	$gatewaydev;

print "<tr> <td><b>$text{'routes_forward'}</b></td> <td>\n";
printf "<input type=radio name=forward value=1 %s> $text{'yes'}\n",
	$conf{'IPFORWARDING'} =~ /yes|true/i ? "checked" : "";
printf "<input type=radio name=forward value=0 %s> $text{'no'}</td> </tr>\n",
	$conf{'IPFORWARDING'} =~ /yes|true/i ? "" : "checked";

print "<tr> <td valign=top><b>$text{'routes_script'}</b></td> <td>\n";
print "<textarea name=script rows=4 cols=60>\n";
open(SCRIPT, $static_route_config);
while(<SCRIPT>) { print; }
close(SCRIPT);
print "</textarea></td> </tr>\n";
}

sub parse_routing
{
local %conf;
&lock_file($network_config);
&read_file($network_config, \%conf);
if ($in{'forward'}) { $conf{'IPFORWARDING'} = 'yes'; }
else { delete($conf{'IPFORWARDING'}); }

if (!$in{'gateway_def'}) {
	gethostbyname($in{'gateway'}) ||
		&error(&text('routes_edefault', $in{'gateway'}));
	-r "$net_scripts_dir/ifcfg-$in{'gatewaydev'}" ||
		&error(&text('routes_edevice', $in{'gatewaydev'}));
	}

&set_default_gateway($in{'gateway_def'} ? ( ) :
			( $in{'gateway'}, $in{'gatewaydev'} ) );

&write_file($network_config, \%conf);
&unlock_file($network_config);

&lock_file($static_route_config);
open(SCRIPT, ">$static_route_config");
$in{'script'} =~ s/\r//g;
print SCRIPT $in{'script'};
close(SCRIPT);
&unlock_file($static_route_config);
&system_logged("chmod +x $static_route_config");
}

sub os_feedback_files
{
opendir(DIR, $net_scripts_dir);
local @f = readdir(DIR);
closedir(DIR);
return ( (map { "$net_scripts_dir/$_" } grep { /^ifcfg-/ } @f),
	 $network_config, $static_route_config, $nis_conf, "/etc/resolv.conf",
	 "/etc/nsswitch.conf", "/etc/HOSTNAME" );
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
system("(cd / ; /etc/rc.d/init.d/network stop ; /etc/rc.d/init.d/network start) >/dev/null 2>&1");
}

# apply_interface(&iface)
# Calls an OS-specific function to make a boot-time interface active
sub apply_interface
{
local $out = &backquote_logged("cd ; ifup '$_[0]->{'fullname'}' 2>&1 </dev/null");
return $? ? $out : undef;
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
&read_file($network_config, \%conf);
opendir(CONF, $net_scripts_dir);
local $f;
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-(\S+)/);
	local %ifc;
	&read_file("$net_scripts_dir/$f", \%ifc);
	if (&check_ipaddress($ifc{'GATEWAY'})) {
		return ( $ifc{'GATEWAY'}, $ifc{'DEVICE'} );
		}
	}
closedir(CONF);
return ( );
}

# set_default_gateway([gateway, device])
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
opendir(CONF, $net_scripts_dir);
local $f;
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-(\S+)/);
	local %ifc;
	&lock_file("$net_scripts_dir/$f");
	&read_file("$net_scripts_dir/$f", \%ifc);
	if (!$_[0] || $ifc{'DEVICE'} ne $_[1]) {
		delete($ifc{'GATEWAY'});
		}
	else {
		$ifc{'GATEWAY'} = $_[0];
		}
	&write_file("$net_scripts_dir/$f", \%ifc);
	&unlock_file("$net_scripts_dir/$f");
	}
closedir(CONF);
}

1;

