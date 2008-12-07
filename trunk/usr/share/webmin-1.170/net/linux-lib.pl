# linux-lib.pl
# Active interface functions for all flavours of linux

# active_interfaces()
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
{
local(@rv, @lines, $l);
open(IFC, "ifconfig -a |");
while(<IFC>) {
	s/\r|\n//g;
	if (/^\S+/) { push(@lines, $_); }
	else { $lines[$#lines] .= $_; }
	}
close(IFC);
foreach $l (@lines) {
	local %ifc;
	$l =~ /^([^:\s]+)/; $ifc{'name'} = $1;
	$l =~ /^(\S+)/; $ifc{'fullname'} = $1;
	if ($l =~ /^(\S+):(\d+)/) { $ifc{'virtual'} = $2; }
	if ($l =~ /inet addr:(\S+)/) { $ifc{'address'} = $1; }
	elsif (!$_[0]) { next; }
	if ($l =~ /Mask:(\S+)/) { $ifc{'netmask'} = $1; }
	if ($l =~ /Bcast:(\S+)/) { $ifc{'broadcast'} = $1; }
	if ($l =~ /HWaddr (\S+)/) { $ifc{'ether'} = $1; }
	if ($l =~ /MTU:(\d+)/) { $ifc{'mtu'} = $1; }
	if ($l =~ /P-t-P:(\S+)/) { $ifc{'ptp'} = $1; }
	$ifc{'up'}++ if ($l =~ /\sUP\s/);
	$ifc{'edit'} = ($ifc{'name'} !~ /^ppp/);
	$ifc{'index'} = scalar(@rv);
	push(@rv, \%ifc);
	}
return @rv;
}

# activate_interface(&details)
# Create or modify an interface
sub activate_interface
{
local $a = $_[0];
local $cmd = "ifconfig $a->{'name'}";
if ($a->{'virtual'} ne "") { $cmd .= ":$a->{'virtual'}"; }
$cmd .= " $a->{'address'}";
if ($a->{'netmask'}) { $cmd .= " netmask $a->{'netmask'}"; }
if ($a->{'broadcast'}) { $cmd .= " broadcast $a->{'broadcast'}"; }
if ($a->{'mtu'}) { $cmd .= " mtu $a->{'mtu'}"; }
if ($a->{'up'}) { $cmd .= " up"; }
else { $cmd .= " down"; }
local $out = &backquote_logged("$cmd 2>&1");
if ($?) { &error($out); }
if ($a->{'ether'}) {
	$out = &backquote_logged(
		"ifconfig $a->{'name'} hw ether $a->{'ether'} 2>&1");
	if ($?) { &error($out); }
	}
}

# deactivate_interface(&details)
# Shutdown some active interface
sub deactivate_interface
{
local $name = $_[0]->{'name'}.
	      ($_[0]->{'virtual'} ne "" ? ":$_[0]->{'virtual'}" : "");
if ($_[0]->{'virtual'} ne "") {
	# Shutdown virtual interface by setting address to 0
	local $out = &backquote_logged("ifconfig $name 0 2>&1");
	}
local ($still) = grep { $_->{'fullname'} eq $name } &active_interfaces();
if ($still) {
	# Old version of ifconfig or non-virtual interface.. down it
	local $out = &backquote_logged("ifconfig $name down 2>&1");
	local ($still) = grep { $_->{'fullname'} eq $name }
			      &active_interfaces();
	if ($still) {
		&error("<pre>$out</pre>");
		}
	}
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
if ($_[0] =~ /^(.*)\.(\d+)$/) {
	return &iface_type("$1")." VLAN";
	}
return "PPP" if ($_[0] =~ /^ppp/);
return "SLIP" if ($_[0] =~ /^sl/);
return "PLIP" if ($_[0] =~ /^plip/);
return "Ethernet" if ($_[0] =~ /^eth/);
return "Wireless Ethernet" if ($_[0] =~ /^wlan/);
return "Arcnet" if ($_[0] =~ /^arc/);
return "Token Ring" if ($_[0] =~ /^tr/);
return "Pocket/ATP" if ($_[0] =~ /^atp/);
return "Loopback" if ($_[0] =~ /^lo/);
return "ISDN rawIP" if ($_[0] =~ /^isdn/);
return "ISDN syncPPP" if ($_[0] =~ /^ippp/);
return "CIPE" if ($_[0] =~ /^cip/);
return "VmWare" if ($_[0] =~ /^vmnet/);
return "Wireless" if ($_[0] =~ /^wlan/);
return $text{'ifcs_unknown'};
}

# list_routes()
# Returns a list of active routes
sub list_routes
{
local @rv;
open(ROUTES, "netstat -rn |");
while(<ROUTES>) {
	s/\s+$//;
	if (/^([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)$/) {
		push(@rv, { 'dest' => $1,
			    'gateway' => $2,
			    'netmask' => $3,
			    'iface' => $4 });
		}
	}
close(ROUTES);
return @rv;
}

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
{
return $_[0] =~ /^eth/;
}

# allow_interface_clash()
# Returns 0 to indicate that two virtual interfaces with the same IP
# are not allowed
sub allow_interface_clash
{
return 0;
}

