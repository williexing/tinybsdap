#!/usr/bin/perl

use CGI qw/:standard :cgi-lib/;
do '../../web-lib.pl';
require './st_lib.pl';

my $mainpage = "net.html";
my $config_file = st_get_conf('network_interface');
my $dhcp_file = st_get_conf('dhcp_conf');
my $hostapd_file = st_get_conf('hostapd_conf');
my @conf=('address','netmask','broadcast','up route add default gw',
	  'wlanaddress');
my @conf_must = ('address','netmask','wlanaddress');
my @conf_eth=('address','netmask','broadcast','up route add default gw');
my @conf_wlan=('wlanaddress');
my @conf_dhcp=('dhcp','dhcpstart','dhcpend');
my @conf_dhcp_ip=('dhcpstart','dhcpend');
my %map_wlan=('wlanaddress' => 'address');
my $confwlan = 'wlanaddress';
my $dhcp = 0;

my %map_wlan_back= ();
foreach(keys %map_wlan) { $map_wlan_back{$map_wlan{$_}} = $_; }

my $state = 1;
sub rs { $state = 0; }

my %info = (1 => 'Network Interfaces updated successfully.',
	    2 => 'An Error occured while trying to reload Network Interfaces,'.
	    ' please try again.',
	    3 => 'Error: IP Address and Netmask are mandatory.',
	    4 => 'Error: Alpha-Numeric Characters and valid IP Address/Hostname are allowed only',
#	    5 => 'Error: Invalid IP Address/Hostname',
	    5 => 'Error: Invalid IP Address',
	    6 => 'Error: Invalid IP Address in DHCP settings',
	    7 => 'Error: DHCP Start and End Range may cover max. 50 IP-Addresses',
	    8 => 'Error: Own IP Address in DHCP Range.',
	    9 => 'Error: WLAN Interface IP Address and DHCP Range must be in the same net.',
	    10 => 'Error: Last Number of DHCP Start Range must be greater 1 and less 254.',
	    11 => 'Error: Last Number of DHCP End Range must be greater 1 and less 254.',
	    );

sub this_get_prefix {
    $input = shift;
    $input =~ s/\.\d+$/\./;
    return $input;
}
sub this_get_no {
    $input = shift;
    $input   =~ s/.*\.(\d+)$/$1/;
    return $input;
}


my %new = ();
foreach(@conf) { $new{$_} = ''; }
foreach(@conf_dhcp) { $new{$_} = ''; }

if (param) {
    if (param('action') eq 'Submit') { 
	my $err = 0;
	my $restart_ok = 1;
	
	foreach(@conf) { $new{$_} = param($_); }
	
	if(param('dhcp') eq 'checked') { $dhcp = 1; }
	
	if ($dhcp) {  
	    foreach(@conf_dhcp) { $new{$_} = param($_); }
	    
	}
	
 	foreach(keys %new) { 
 	    if (st_bad_char($new{$_})) {
 		$new{'info'} = $info{4};
 		$err++;
 	    }
 	}
	
	foreach(@conf_must) { 
	    if (($new{$_} eq '')) {
		$new{'info'} = $info{3};
		$err++;
	    }
	}
	foreach(@conf) { 
	    if (! (($new{$_} eq '') || st_ip($new{$_}))) {
		$new{'info'} = $info{5};
		$err++;
	    }
	}
	
	if ($dhcp && (!$err)) {
	    foreach(@conf_dhcp_ip) { 
		if (!st_ip(param($_)))  {
		    $new{'info'} = $info{6};
		    $err++;
		}
	    }
	    $wlanprefix = this_get_prefix($new{$confwlan});
	    $startpref = this_get_prefix($new{'dhcpstart'});
	    $endpref = this_get_prefix($new{'dhcpend'});
	    
	    $wlanno = this_get_no($new{$confwlan});
	    $startno = this_get_no($new{'dhcpstart'});
	    $endno = this_get_no($new{'dhcpend'});
	    
	    if (($wlanprefix ne $startpref) || 
		($wlanprefix ne $endpref)){
		$new{'info'} = $info{9};
		$err++;
	    } else {
		if (($endno - $startno) > 49) {
		    $new{'info'} = $info{7};
		    $err++;
		}
		if (($wlanno <= $endno) && ($wlanno >= $endno)) {
		    $new{'info'} = $info{8};
		    $err++;
		}
		if (($startno <= 1) || ($startno > 253)) {
		    $new{'info'} = $info{10};
		    $err++;
		}
		if (($startno <= 1) || ($startno > 253)) {
		    $new{'info'} = $info{11};
		    $err++;
		}
	    }
	}
	    
	if($err) {
	    st_output2($mainpage,\%new);
	    rs();
	} else {

	    st_write_iface(\%new);
	    
	    if ($dhcp) {
		if (!st_dhcp_start($wlanprefix."0",
				   $new{'dhcpstart'},$new{'dhcpend'},
				   $new{$confwlan}))
{
		    $restart_ok = 0; 
		}
	    } else {
		st_dhcp_stop();
	    }
	    
	    if (param('do') eq 'Update Backbone Interface') { 
		if (!st_restart_iface_eth0()) { $restart_ok = 0; }
		my %hostapd = ('own_ip_addr' => $new{'address'});
		st_write_config($hostapd_file,\%hostapd);
	    }

	    if (param('do') eq 'Update WLAN Interface') { 
		if (!st_restart_iface_wlan0()) { $restart_ok = 0; }
	    }
	    
	    if ($restart_ok) { 
		$new{'info'} = $info{1};
		if ($dhcp) {
		    $new{'info'} = $new{'info'}."<br> DHCP is activated now.";
		}
	    } else { 
		$new{'info'} = $info{2};
		st_output2($mainpage,\%new);
		rs();
	    }
	    # $new{'info'} = $new{'info'}." wlan = ".$wlanprefix;
	}
    }
}
		      
if($state) { 
    foreach(@conf) { $new{$_} = ''; }
    if(st_isFile($config_file)) {
	my $content_eth = st_get_html($config_file);
	my $content_wlan = st_get_html($config_file);
	my $any = '(.|\n)*';
	my $expr = "auto".$any."loopback";
	$content_eth =~ s/$expr//g;
	$expr = 'auto\s*wlan'.$any."auto eth0";
	$content_eth =~ s/$expr//g;
	
	$expr = "auto".$any."loopback";
	$content_wlan =~ s/$expr//;
	$expr = 'auto\s*eth'.$any;
	$content_wlan =~ s/$expr//;
	foreach(@conf_eth) {
	    if ($content_eth =~ /$_[[:blank:]]+([^[:blank:]]+)\n/) {
		$new{$_} = $1;
	    } else { $new{$_} = ""; }
	}
	
	foreach(keys %map_wlan_back) {
	    if ($content_wlan =~ /$_[[:blank:]]+([^[:blank:]]+)\n/) {
		$new{$map_wlan_back{$_}} = $1;
	    } else { $new{$map_wlan_back{$_}} = '';}
	}
	if(st_is_dhcp()) { 
	    $new{'dhcp'} = 'checked'; 
	    ($new{'dhcpstart'},$new{'dhcpend'}) = st_get_dhcp();
	} 
	else { 
	    $new{'dhcp'} = ''; 
	    $new{'dhcpstart'} = ''; 
	    $new{'dhcpend'} = ''; 
	} 
    }
    st_output2($mainpage,\%new);
}

