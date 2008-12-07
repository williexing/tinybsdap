# slackware-linux-lib.pl
# Networking functions for slackware linux
# To support boot-time interfaces, ifconfig commands are added to rc.local so
# that additional virtual interfaces can be created

do 'linux-lib.pl';
%iconfig = &foreign_config("init");
$interfaces_file = $iconfig{'local_script'} || $iconfig{'extra_init'};
$rc_init = "/etc/rc.d/rc.inet1";
$dhcp_init = "/etc/rc.d/rc.dhcpd";

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local @rv;

# Look in rc.init1 file for master interface
local $iface = { 'up' => 1,
		 'edit' => 1,
		 'index' => 0,
		 'init' => 1,
		 'name' => 'eth0',
		 'fullname' => 'eth0',
		 'file' => $rc_init };
local $gotdevice;
open(INIT, $rc_init);
while(<INIT>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*IPADDR\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'address'} = $1;
		}
	elsif (/^\s*DEVICE\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'name'} = $iface->{'fullname'} = $1;
		$gotdevice++;
		}
	elsif (/^\s*NETMASK\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'netmask'} = $1;
		}
	elsif (/^\s*BROADCAST\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'broadcast'} = $1;
		}
	elsif (/^\s*DHCP\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'dhcp'} = ($1 eq "yes");
		}
	elsif (/^\s*ifconfig\s+(\S+)\s+.*IPADDR.*/ && !$gotdevice) {
		$iface->{'name'} = $iface->{'fullname'} = $1;
		}
	}
close(INIT);
local @st1 = stat($rc_init);
local @st2 = stat($dhcp_init);
if ($st1[7] == $st2[7]) {
	# Looks like rc.dhcpd script has been copied to rc.inet1 - assume DHCP
	$iface->{'dhcp'} = 1;
	}
push(@rv, $iface) if ($iface->{'address'} || $iface->{'dhcp'});

# Read extra init script for virtual interfaces
local $lnum = 0;
open(IFACES, $interfaces_file);
while(<IFACES>) {
	s/\r|\n//g;
	if (/^(#*)\s*(\S*ifconfig)\s+(\S+)\s+(\S+)(\s+netmask\s+(\S+))?(\s+broadcast\s+(\S+))?(\s+mtu\s+(\d+))?\s+up$/) {
		# Found a usable interface line
		local $b = { 'fullname' => $3,
			     'up' => !$1,
			     'address' => $4,
			     'netmask' => $6,
			     'broadcast' => $8,
			     'mtu' => $10,
			     'edit' => 1,
			     'line' => $lnum,
			     'file' => $interfaces_file,
			     'index' => scalar(@rv) };
		if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
			$b->{'name'} = $1;
			$b->{'virtual'} = $2;
			}
		else {
			$b->{'name'} = $b->{'fullname'};
			}
		push(@rv, $b);
		}
	$lnum++;
	}
close(IFACES);
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface's ifconfig command
sub save_interface
{
if ($_[0]->{'index'} == 0 && $_[0]->{'fullname'} eq 'eth0') {
	# Modifying the primary interface
	&lock_file($rc_init);
	if ($_[0]->{'dhcp'} && -r $dhcp_init) {
		# Just copy rc.dhcpd to rc.inet1
		system("cp $dhcp_init $rc_init");
		}
	else {
		# Is the current file rc.dhcpd?
		if (!$_[0]->{'dhcp'}) {
			local @st1 = stat($rc_init);
			local @st2 = stat($dhcp_init);
			if ($st1[7] == $st2[7]) {
				# Yes! Use built-in static IP version
				system("cp $module_root_directory/rc.inet1 $rc_init");
				}
			}

		# Update init script with new settings
		local $lref = &read_file_lines($rc_init);
		foreach $l (@$lref) {
			if ($l =~ /^(\s*)IPADDR\s*=\s*(\S+)(.*)/) {
				$l = $1."IPADDR=\"".$_[0]->{'address'}."\"".$3;
				}
			elsif ($l =~ /^(\s*)NETMASK\s*=\s*(\S+)(.*)/) {
				$l = $1."NETMASK=\"".$_[0]->{'netmask'}."\"".$3;
				}
			elsif ($l =~ /^(\s*)BROADCAST\s*=\s*(\S+)(.*)/) {
				$l = $1."BROADCAST=\"".$_[0]->{'broadcast'}."\"".$3;
				}
			if ($l =~ /^(\s*)DHCP\s*=\s*(\S+)(.*)/) {
				$l = $1."DHCP=\"".($_[0]->{'dhcp'} ? "yes" : "no")."\"".$3;
				}
			}
		&flush_file_lines();
		}
	&unlock_file($rc_init);
	}
else {
	# Modifying or adding some other interface
	$_[0]->{'dhcp'} && &error($text{'bifc_edhcpmain'});
	&lock_file($interfaces_file);
	local $lref = &read_file_lines($interfaces_file);
	local $lnum = defined($_[0]->{'line'}) ? $_[0]->{'line'}
					       : &interface_lnum($_[0]);
	if (defined($lnum)) {
		$lref->[$lnum] = &interface_line($_[0]);
		}
	else {
		push(@$lref, &interface_line($_[0]));
		}
	&flush_file_lines();
	&unlock_file($interfaces_file);
	}
}

# delete_interface(&details)
# Delete a boot-time interface's ifconfig command
sub delete_interface
{
if ($_[0]->{'init'}) {
	&error("The primary network interface cannot be deleted");
	}
else {
	&lock_file($interfaces_file);
	local $lref = &read_file_lines($interfaces_file);
	local $lnum = defined($_[0]->{'line'}) ? $_[0]->{'line'}
					       : &interface_lnum($_[0]);
	if (defined($lnum)) {
		splice(@$lref, $lnum, 1);
		}
	&flush_file_lines();
	&unlock_file($interfaces_file);
	}
}

sub interface_lnum
{
local @boot = &boot_interfaces();
local ($found) = grep { $_->{'fullname'} eq $_[0]->{'fullname'} } @boot;
return $found ? $found->{'line'} : undef;
}

sub interface_line
{
local $str;
$str .= "# " if (!$_[0]->{'up'});
$str .= &has_command("ifconfig");
if (!$_[0]->{'fullname'}) {
	$_[0]->{'fullname'} = $_[0]->{'virtual'} ne "" ?
		$_[0]->{'name'}.":".$_[0]->{'virtual'} : $_[0]->{'name'};
	}
$str .= " $_[0]->{'fullname'} $_[0]->{'address'}";
if ($_[0]->{'netmask'}) {
	$str .= " netmask $_[0]->{'netmask'}";
	}
if ($_[0]->{'broadcast'}) {
	$str .= " broadcast $_[0]->{'broadcast'}";
	}
if ($_[0]->{'mtu'}) {
	$str .= " mtu $_[0]->{'mtu'}";
	}
$str .= " up";
return $str;
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] ne "bootp";
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
	local @srcs = ( "", "files", "dns", "nis", "nisplus", "ldap", "db" );
	local @srcn = ( "", "Hosts", "DNS", "NIS", "NIS+", "LDAP", "DB" );
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
&system_logged("hostname $_[0] >/dev/null 2>&1");
&lock_file("/etc/HOSTNAME");
open(HOST, ">/etc/HOSTNAME");
print HOST $_[0],"\n";
close(HOST);
&unlock_file("/etc/HOSTNAME");
}

sub routing_config_files
{
return ( $rc_init );
}

sub routing_input
{
open(INIT, $rc_init);
while(<INIT>) {
	s/\r|\n//g;
        s/#.*$//;
	if (/^\s*GATEWAY\s*=\s*["']?([0-9\.]+)/) {
		$gw = $1;
		}
	}
close(INIT);
print "<tr> <td><b>$text{'routes_default'}</b></td> <td>\n";
printf "<input type=radio name=default value=1 %s> %s\n",
	$gw ? "" : "checked", $text{'routes_none'};
printf "<input type=radio name=default value=0 %s> %s\n",
	$gw ? "checked" : "", $text{'routes_gateway'};
printf "<input name=gw size=20 value='%s'></td> </tr>\n", $gw;
}

sub parse_routing
{
local $gw = "";
if (!$in{'default'}) {
	&check_ipaddress($in{'gw'}) ||
		&error(&text('routes_edefault', $in{'gw'}));
	$gw = $in{'gw'};
	}
&lock_file($rc_init);
local $lref = &read_file_lines($rc_init);
foreach $l (@$lref) {
	if ($l =~ /^(\s*)GATEWAY\s*=\s*(\S+)(.*)/) {
		$l = $1."GATEWAY=\"".$gw."\"".$3;
		}
	}
&flush_file_lines();
&unlock_file($rc_init);
}



1;

