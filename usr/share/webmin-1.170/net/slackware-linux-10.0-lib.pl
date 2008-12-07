# slackware-linux-9.1-lib.pl
# Networking functions for slackware linux 9.1 and above. Unlike older releases
# of slackware, this one actually has a networking config file!!

do 'linux-lib.pl';
$inet_conf = "/etc/rc.d/rc.inet1.conf";
%iconfig = &foreign_config("init");
$interfaces_file = $iconfig{'local_script'} || $iconfig{'extra_init'};

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local @rv;
local $iface;

# Add loopback
push(@rv, { 'up' => 1,
	    'init' => 1,
	    'edit' => 0,
	    'name' => 'lo',
	    'fullname' => 'lo',
	    'address' => '127.0.0.1',
	    'netmask' => '255.0.0.0' } );

# Look in inet1.conf file for master interfaces
local $lnum = 0;
open(CONF, $inet_conf);
while(<CONF>) {
	if (/^\s*IPADDR\[(\d+)\]\s*=\s*"(.*)"/) {
		push(@rv, { 'up' => 1,
			    'init' => 1,
			    'edit' => 1,
			    'address' => $2,
			    'line' => $lnum,
			    'eline' => $lnum,
			    'number' => $1,
			    'file' => $inet_conf,
			    'name' => 'eth'.$1,
			    'fullname' => 'eth'.$1 });
		}
	elsif (/^\s*NETMASK\[(\d+)\]\s*=\s*"(.*)"/ && @rv) {
		$rv[$#rv]->{'netmask'} = $2;
		if ($2 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/ &&
		    $rv[$#rv]->{'address'}) {
			local ($a1, $a2, $a3, $a4) =
				split(/\./, $rv[$#rv]->{'address'});
			$rv[$#rv]->{'broadcast'} = sprintf "%d.%d.%d.%d",
						($a1 | ~int($1))&0xff,
						($a2 | ~int($2))&0xff,
						($a3 | ~int($3))&0xff,
						($a4 | ~int($4))&0xff;
			}
		$rv[$#rv]->{'eline'} = $lnum;
		}
	elsif (/^\s*USE_DHCP\[(\d+)\]\s*=\s*"(.*)"/ && @rv) {
		$rv[$#rv]->{'dhcp'} = 1 if (lc($2) eq "yes");
		$rv[$#rv]->{'eline'} = $lnum;
		}
	elsif (/^\s*\S+\[(\d+)\]\s*=\s*"(.*)"/ && @rv) {
		# Some other directive in the current section
		$rv[$#rv]->{'eline'} = $lnum;
		}
	$lnum++;
	}
close(CONF);

# Filter out any unset
@rv = grep { $_->{'address'} || $_->{'dhcp'} } @rv;
local $i;
for($i=0; $i<@rv; $i++) {
	$rv[$i]->{'index'} = $i;
	}

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
# Find in existing config
local @boot = &boot_interfaces();
local ($old) = grep { $_->{'fullname'} eq $_[0]->{'fullname'} } @boot;

if ($old && $old->{'init'}) {
	# Modifying in inet1.conf file
	&lock_file($inet_conf);
	local $lref = &read_file_lines($inet_conf);
	local $i;
	for($i=$old->{'line'}; $i<=$old->{'eline'}; $i++) {
		if ($lref->[$i] =~ /^\s*IPADDR\[(\d+)\]\s*=\s*"(.*)"/) {
			$lref->[$i] = "IPADDR\[$1\]=\"$_[0]->{'address'}\"";
			}
		elsif ($lref->[$i] =~ /^\s*NETMASK\[(\d+)\]\s*=\s*"(.*)"/) {
			$lref->[$i] = "NETMASK\[$1\]=\"$_[0]->{'netmask'}\"";
			}
		elsif ($lref->[$i] =~ /^\s*USE_DHCP\[(\d+)\]\s*=\s*"(.*)"/) {
			local $dhcp = $_[0]->{'dhcp'} ? "yes" : "";
			$lref->[$i] = "USE_DHCP\[$1\]=\"$dhcp\"";
			}
		}
	&flush_file_lines();
	&unlock_file($inet_conf);
	}
elsif (!$old && $_[0]->{'fullname'} =~ /^eth([0-3])$/) {
	# Adding to inet1.conf file, in the appropriate empty section
	local $num = $1;
	&lock_file($inet_conf);
	local $lref = &read_file_lines($inet_conf);
	local $i;
	for($i=0; $i<@$lref; $i++) {
		if ($lref->[$i] =~ /^\s*IPADDR\[(\d+)\]\s*=\s*"(.*)"/ &&
		    $1 == $num) {
			$lref->[$i] = "IPADDR\[$1\]=\"$_[0]->{'address'}\"";
			}
		elsif ($lref->[$i] =~ /^\s*NETMASK\[(\d+)\]\s*=\s*"(.*)"/ &&
		       $1 == $num) {
			$lref->[$i] = "NETMASK\[$1\]=\"$_[0]->{'netmask'}\"";
			}
		elsif ($lref->[$i] =~ /^\s*USE_DHCP\[(\d+)\]\s*=\s*"(.*)"/ &&
		       $1 == $num) {
			local $dhcp = $_[0]->{'dhcp'} ? "yes" : "";
			$lref->[$i] = "USE_DHCP\[$1\]=\"$dhcp\"";
			}
		}
	&flush_file_lines();
	&unlock_file($inet_conf);
	}
else {
	# Modifying or adding some other interface in separate file
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
# Find in existing config
local @boot = &boot_interfaces();
local ($old) = grep { $_->{'fullname'} eq $_[0]->{'fullname'} } @boot;

if ($old && $old->{'init'}) {
	# Deleting from inet1.conf file .. just set to blank
	&lock_file($inet_conf);
	local $lref = &read_file_lines($inet_conf);
	local $i;
	for($i=$old->{'line'}; $i<=$old->{'eline'}; $i++) {
		if ($lref->[$i] =~ /^\s*(\S+)\[(\d+)\]\s*=\s*"(.*)"/) {
			$lref->[$i] = "$1\[$2\]=\"\"";
			}
		}
	&flush_file_lines();
	&unlock_file($inet_conf);
	}
else {
	# Deleting from separate file
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
return ( $inet_conf );
}

sub routing_input
{
open(INIT, $inet_conf);
while(<INIT>) {
	s/\r|\n//g;
        s/#.*$//;
	if (/^\s*GATEWAY\s*=\s*"(.*)"/) {
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
&lock_file($inet_conf);
local $lref = &read_file_lines($inet_conf);
foreach $l (@$lref) {
	if ($l =~ /^(\s*)GATEWAY\s*=\s*"(.*)"(.*)/) {
		$l = $1."GATEWAY=\"".$gw."\"".$3;
		}
	}
&flush_file_lines();
&unlock_file($inet_conf);
}


