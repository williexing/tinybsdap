# net-lib.pl
# Common local networking functions

do '../web-lib.pl';
&init_config();
require '../ui-lib.pl';
%access = &get_module_acl();

if (-r "$module_root_directory/$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl") {
	do "$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}

# list_hosts()
# Parse hosts from /etc/hosts into a data structure
sub list_hosts
{
local @rv;
local $lnum = 0;
open(HOSTS, $config{'hosts_file'});
while(<HOSTS>) {
	s/\r|\n//g;
	s/#.*$//g;
	s/\s+$//g;
	if (/(\d+\.\d+\.\d+\.\d+)\s+(.*)$/) {
		push(@rv, { 'address' => $1,
			    'hosts' => [ split(/\s+/, $2) ],
			    'line', $lnum,
			    'index', scalar(@rv) });
		}
	$lnum++;
	}
close(HOSTS);
return @rv;
}

# create_host(&host)
# Add a new host to /etc/hosts
sub create_host
{
open(HOSTS, ">>$config{'hosts_file'}");
print HOSTS $_[0]->{'address'},"\t",join(" ",@{$_[0]->{'hosts'}}),"\n";
close(HOSTS);
}

# modify_host(&host)
# Update the address and hosts of a line in /etc/hosts
sub modify_host
{
&replace_file_line($config{'hosts_file'},
		   $_[0]->{'line'},
		   $_[0]->{'address'}."\t".join(" ",@{$_[0]->{'hosts'}})."\n");
}

# delete_host(&host)
# Delete a host from /etc/hosts
sub delete_host
{
&replace_file_line($config{'hosts_file'}, $_[0]->{'line'});
}

# parse_hex(hex)
# Convert an address like ff000000 into 255.0.0.0
sub parse_hex
{
$_[0] =~ /(..)(..)(..)(..)$/;
return join(".", (hex($1), hex($2), hex($3), hex($4)));
}

# interfaces_chooser_button(field, multiple, [form])
# Returns HTML for a javascript button for choosing an interface or interfaces
sub interfaces_chooser_button
{
  local $form = @_ > 2 ? $_[2] : 0;
  local $w = $_[1] ? 500 : 300;
  return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/net/interface_chooser.cgi?multi=$_[1]&interface=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=200\"); chooser.ifield = ifield' value=\"...\">\n";
}

# prefix_to_mask(prefix)
# Converts a number like 24 to a mask like 255.255.255.0
sub prefix_to_mask
{
return $_[0] >= 24 ? "255.255.255.".(256-(2 ** (32-$_[0]))) :
       $_[0] >= 16 ? "255.255.".(256-(2 ** (24-$_[0]))).".0" :
       $_[0] >= 16 ? "255.".(256-(2 ** (16-$_[0]))).".0.0" :
		     (256-(2 ** (8-$_[0]))).".0.0.0";
}

# mask_to_prefix(mask)
# Converts a mask like 255.255.255.0 to a prefix like 24
sub mask_to_prefix
{
return $_[0] =~ /^255\.255\.255\.(\d+)$/ ? 32-&log2(256-$1) :
       $_[0] =~ /^255\.255\.(\d+)\.0$/ ? 24-&log2(256-$1) :
       $_[0] =~ /^255\.(\d+)\.0\.0$/ ? 16-&log2(256-$1) :
       $_[0] =~ /^(\d+)\.0\.0\.0$/ ? 8-&log2(256-$1) : 32;
}

sub log2
{
return int(log($_[0])/log(2));
}

# module_for_interface(&interface)
# Returns a structure containing details of some other module that manages
# some active interface
sub module_for_interface
{
return undef if ($_[0]->{'name'} !~ /^ppp/);	# only for PPP
if (&foreign_check("ppp-client")) {
	# Dialup PPP connection
	&foreign_require("ppp-client", "ppp-client-lib.pl");
	local ($ip, $pid, $sect) = &ppp_client::get_connect_details();
	if ($ip eq $_[0]->{'address'}) {
		return { 'module' => 'ppp-client',
			 'desc' => &text('mod_ppp', $sect) };
		}
	}
if (&foreign_check("adsl-client")) {
	# ADSL PPP connection
	&foreign_require("adsl-client", "adsl-client-lib.pl");
	local ($dev, $ip) = &adsl_client::get_adsl_ip();
	if ("ppp$dev" eq $_[0]->{'fullname'}) {
		return { 'module' => 'adsl-client',
			 'desc' => &text('mod_adsl') };
		}
	}
if (&foreign_check("pap")) {
	# Dialin PPP connection
	# XXX not handled yet
	}
if (&foreign_check("pptp-client")) {
	# PPTP client connection
	&foreign_require("pptp-client", "pptp-client-lib.pl");
	local @tunnels = &pptp_client::list_tunnels();
	local %tunnels = map { $_->{'name'}, 1 } @tunnels;
	local @conns = &pptp_client::list_connected();
	foreach $c (@conns) {
		if ($c->[2] eq $_[0]->{'fullname'}) {
			return { 'module' => 'pptp-client',
				 'desc' => &text('mod_pptpc', "<i>$c->[0]</i>") };
			}
		}
	}
if (&foreign_check("pptp-server")) {
	# PPTP server connection
	&foreign_require("pptp-server", "pptp-server-lib.pl");
	local @conns = &pptp_server::list_connections();
	local $c;
	foreach $c (@conns) {
		if ($c->[3] eq $_[0]->{'fullname'} ||
		    $c->[4] eq $_[0]->{'address'}) {
			return { 'module' => 'pptp-server',
				 'desc' => &text('mod_pptps', $c->[2]) };
			}
		}
	}
return undef;
}

# can_iface(name)
sub can_iface
{
local $name = ref($_[0]) && $_[0]->{'fullname'} ? $_[0]->{'fullname'} :
	      ref($_[0]) ? $_[0]->{'name'}.
		   ($_[0]->{'virtual'} ne "" ? ":$_[0]->{'virtual'}" : "") :
		   $_[0];
return 0 if ($access{'ifcs'} == 0 || $access{'ifcs'} == 1);
return 1 if ($access{'ifcs'} == 2);
local %can = map { $_, 1 } split(/\s+/, $access{'interfaces'});
if ($access{'ifcs'} == 3) {
	return $can{$name};
	}
else {
	return !$can{$name};
	}
}

sub can_create_iface
{
return $access{'ifcs'} == 2;
}

1;

