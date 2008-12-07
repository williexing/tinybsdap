# gentoo-linux-lib.pl
# Networking functions for gentoo linux


use Data::Dumper;

$net_config = "/etc/conf.d/net";
$routes_config = "/etc/conf.d/routes";
$sysctl_config = "/etc/sysctl.conf";

## This is a template for the net startscripts used for starting interfaces at boot time
#  I'm not quite sure but I think the one for the first Interface comes with gentoo.
$net_template = "/etc/init.d/net.eth0";

## Since Gentoo starts and stops interfaces like daemons these directories are needed.
$init_scripts = "/etc/init.d";
$boot_scripts = "/etc/runlevels/default";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
my %nconfig;
&read_env_file($net_config, \%nconfig);
foreach $f (sort keys %nconfig) {
	local (%conf, $b);
	## [Gentoo] If we've got a physical Interface
	if ($f =~ /^iface_([a-z]+\d*(\.\d+)?)$/) {

		## [Gentoo] Set IP, Netmask, Broadcast.Interface is to be
		#  started at boot-time if start stript is found in the default
		#  runlevel directoriy (etc/runlevels/default)
		$b->{'name'} = $1;
		$b->{'fullname'} = $b->{'name'};

		## [Gentoo] Push the configuration string into an
		#  array to take care of wich arg is which.
		local @config_string = split(/\s+/,$nconfig{$f});
		if($config_string[0] eq 'dhcp') {
			$b->{'dhcp'} = 'dhcp';
		}
		$b->{'address'} = $config_string[0];
		$b->{$config_string[1]} = $config_string[2];
		$b->{$config_string[3]} = $config_string[4];
		if(-e $boot_scripts . '/net.' . $b->{'name'}) {
			$b->{'up'} = 'onboot';
		} else {
			$b->{'up'} = '';
		}
		$b->{'edit'} = ($b->{'name'} !~ /^ppp|irlan/);
	        $b->{'index'} = scalar(@rv);
		$b->{'virtual'} = '';
		$b->{'file'} = $net_config;

	## [Gentoo] For Aliases. This is a bit difficult. they are stored space-seperated.
	#  So we'll push them as arrays into a href per interface
	} elsif ($f =~ /^alias_([a-z]+\d*(\.\d+)?)$/) {
		@{$addresses{$1}} =  split(/\s+/,$nconfig{$f});
		next;
	} elsif ($f =~ /^broadcast_([a-z]+\d*(\.\d+)?)$/) {
		@{$broadcasts{$1}} = split(/\s+/,$nconfig{$f});
		next;
	} elsif ($f =~ /^netmask_([a-z]+\d*(\.\d+)?)$/) {
		@{$netmasks{$1}} = split(/\s+/,$nconfig{$f});
		next;
	} else {
		next;
	}
push(@rv, $b);
}

	# [Gentoo] Push the Alias Interfaces into the array as well.
	foreach (sort keys %addresses) {
		for $i (0 .. (scalar(@{$addresses{$_}})-1)) {
			local $p;
			$p->{'name'} = $_;
			$p->{'fullname'} = $_ . ":" . $i;
			$p->{'broadcast'} = @{$broadcasts{$_}}[$i];
			$p->{'netmask'} = @{$netmasks{$_}}[$i];
			$p->{'address'} = @{$addresses{$_}}[$i];
			$p->{'virtual'} = $i;
			if(-e $boot_scripts . '/net.' . $p->{'name'}) {
				$p->{'up'} = 'onboot';
			} else {
				$p->{'up'} = '';
			}
			$p->{'edit'} = 1;
			$p->{'index'} = scalar(@rv);
			$p->{'file'} = $net_config;
			push(@rv, $p);
		}
	}
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local(%conf);
&lock_file("$net_config");
&read_env_file("$net_config", \%conf);

## [Gentoo] If we have a normal Interface, we'll just write out the config line.
if($_[0]->{'virtual'} eq "") {
	if($_[0]->{'dhcp'}) {
		$conf{'iface_' . $_[0]->{'name'}} = 'dhcp';
	} else {
		$conf{'iface_' . $_[0]->{'name'}} = $_[0]->{'address'} . 
				    " broadcast " .
				    $_[0]->{'broadcast'} . 
				    " netmask " .
				    $_[0]->{'netmask'};
	}
} else {
	
## [Gentoo] We don't need to check if an alias of the given address already exists, since
#  save_iface.cgi does this already.
	$conf{'alias_' . $_[0]->{'name'}} .= " " . $_[0]->{'address'};
	$conf{'broadcast_' . $_[0]->{'name'}} .= " " . $_[0]->{'broadcast'};
	$conf{'netmask_' . $_[0]->{'name'}} .= " " .$_[0]->{'netmask'};
}

## [Gentoo] Need some Quotes and get rid of leading or ending spaces ..
foreach(sort keys %conf) {
	$conf{$_} =~ s/^\s*//g;
	$conf{$_} =~ s/\s*$//g;
	if($conf{$_}) {
		$write{$_} = '"' . $conf{$_} . '"';
	}

}

&write_file("$net_config", \%write);
&unlock_file("$net_config");

## [Gentoo] If Interface is to be started at boot time,
#  create a link in the default runlevel directory. Else delete it if exists.
if(($_[0]->{'up'} == 1) && (!-e $boot_scripts . "/net." . $_[0]->{'name'})) {
	
	## [Gentoo] Some time we'll need to create a start script first.
	if(!-e $init_scripts . "/net." . $_[0]->{'name'}) {
		&lock_file($init_scripts . "/net." . $_[0]->{'name'});
		open(IN, $net_template);
		open(OUT, ">" . $init_scripts . "/net." . $_[0]->{'name'});
			&copydata(\*IN, \*OUT);
		close IN;
		close OUT;
		&unlock_file($init_scripts . "/net." . $_[0]->{'name'});
		chmod oct("0755"), $init_scripts . "/net." . $_[0]->{'name'};
	}
	&lock_file($boot_scripts . "/net." . $_[0]->{'name'});
	symlink($init_scripts . "/net." . $_[0]->{'name'}, $boot_scripts . "/net." . $_[0]->{'name'});
	&unlock_file($boot_scripts . "/net." . $_[0]->{'name'});
} elsif (($_[0]->{'up'} == 0) && (-e $boot_scripts . "/net." . $_[0]->{'name'})) {
	&lock_file($boot_scripts . "/net." . $_[0]->{'name'});
	unlink($boot_scripts . "/net." . $_[0]->{'name'});
	&unlock_file($boot_scripts . "/net." . $_[0]->{'name'});
}

}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local(%conf);
&lock_file("$net_config");
&read_env_file("$net_config", \%conf);

## [Gentoo] If we have a normal Interface, delete the line.
if($_[0]->{'virtual'} eq "") {
	undef($conf{'iface_' . $_[0]->{'name'}});
} else {

	## [Gentoo] First push Data into array, undef given array_seq, set it again for wrtiting
	#  Do this for the alias-, the netmask- and the broadcastline.
	foreach my $t('alias', 'netmask', 'broadcast') {
		local @ta = split(/\s+/, $conf{$t . '_' . $_[0]->{'name'}});
		undef(@ta[$_[0]->{'virtual'}]);
		$conf{$t . '_' . $_[0]->{'name'}} = join(' ', @ta);
	}
}

## [Gentoo] Need some Quotes ..
foreach(sort keys %conf) {
	$conf{$_} =~ s/^\s*//g;
	$conf{$_} =~ s/\s*$//g;
	if($conf{$_}) {
                $write{$_} = '"' . $conf{$_} . '"';
        }
}

&write_file("$net_config", \%write);
&unlock_file("$net_config");

## [Gentoo] Now delete the boot script
&lock_file($boot_scripts . "/net." . $_[0]->{'name'});
unlink($boot_scripts . "/net." . $_[0]->{'name'});
&unlock_file($boot_scripts . "/net." . $_[0]->{'name'});

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
&lock_file("/etc/hostname");
open(HOST, ">/etc/hostname");
print HOST $_[0],"\n";
close(HOST);
&unlock_file("/etc/hostname");
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
return ( $routes_config, $net_config, $sysctl_config );
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

## [Gentoo] This is a workaround since Gentoo stores gateway Information in the net_config file

&lock_file($net_config);
&read_env_file($net_config, \%gwif);
&unlock_file($net_config);

## [Gentoo] Push the standard gateway Information into @routes using the given format.

local @gwifad = split(/\//, $gwif{'gateway'});
push(local @gwline, 'default', $gwifad[1], undef, $gwifad[0]);
push(@routes, \@gwline) if (@gwline);

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
	$sysctl{'net.ipv4.ip_forward'} eq '1' ? "checked" : "";
printf "<input type=radio name=forward value=0 %s> $text{'no'}</td> </tr>\n",
	$sysctl{'net.ipv4.ip_forward'} eq '1' ? "" : "checked";

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
	
	## [Gentoo] Get the default gw's entry and write it to net_config file instead of routes_config
	if(grep { $_ eq "default" } @$r) {
		local $gwif;
		local %nconfig;
		if(($$r[3] eq "") && ($$r[1] ne "")) {
			
			## If a gateway but no device is provided, get the device.
			$gwif = &get_gw_if($$r[1]);
		} elsif(($$r[4] eq "") && ($$r[1] eq "")) {

			## If neither gateway nor device is provided, don't care bout it.
			next;
		} else {
			$gwif = $$r[3];
		}

		## Now write it all into the file
		&lock_file($net_config);
		&read_env_file($net_config, \%nconfig);
		$nconfig{'gateway'} = $gwif . "/" . $$r[1];
		foreach(sort keys %nconfig) {
		        $nconfig{$_} =~ s/^\s*//g;
	       		$nconfig{$_} =~ s/\s*$//g;
	      		if($nconfig{$_}) {
               			$write{$_} = '"' . $nconfig{$_} . '"';
			}
       		}
		&write_file($net_config, \%write);
		&unlock_file($net_config);

	## The rest is as it was.
	} else {
		print ROUTES join(" ", map { $_ eq '' ? "-" : $_ } @$r),"\n";
	}
}
close(ROUTES);
local $lref = &read_file_lines($sysctl_config);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^\s*net\.ipv4\.ip_forward\s*=/) {
		$lref->[$i] = "net.ipv4.ip_forward = ".($in{'forward'} ? 1 : 0);
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
	 "/etc/nsswitch.conf", "/etc/hostname" );
}

## [Gentoo] Gentoo needs to know the interface through which to reach the gateway
#  (Uses the dev option with route)
sub get_gw_if
{
	local $ip = shift;
	local $gwdel = 'route del default';
	&backquote_logged("$gwdel 2>&1");
	local $gwadd = 'route add default gw ' . $ip;
	&backquote_logged("$gwadd 2>&1") ;
	open(ROUTE, "route -n |");
	while(<ROUTE>) {
		s/\r|\n//g;
		if($_ =~ /\d+/) {
			local($dest, $gw, $mask, $flags, $met, $ref, $use, $if) = split(/\s+/, $_);
			if($gw eq $ip) {
				return $if;
			}
		}
	}
	close ROUTE;
}

1;

