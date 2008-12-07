#!/usr/bin/perl

use CGI qw/:standard :cgi-lib/;
do '../../web-lib.pl';
require './st_lib.pl';

my $state = 1;
my $mainpage = "auth.html";
sub rs { $state = 0; }
my $config_file = st_get_conf('hostapd_conf');
my $secureap_file = st_get_conf('secureap_conf');

my %conf_html = ('auth_server_ip' => '',
		 'auth_server_shared_secret' => '',
		 'auth_server_re_shared_secret' => '',
		 "radius_retry_primary_interval" => '');
my %conf = ('auth_server_shared_secret' => '',
	    "radius_retry_primary_interval" => '');

my %conf_ap = ('auth_server_ip' => '');

my $confc="auth_server_addr";
my $confs="auth_server_port";
my $confn="auth_server_shared_secret";
my $confr="auth_server_re_shared_secret";
my $confz="radius_retry_primary_interval";
my $confi="auth_server_ip";

my %msg = (1 => 'New Settings are updated now',
	   #2 => 'Port Number is invalid, please try again.',
	   3 => 'IP Address is invalid, pleasy try again',
	   4 => 'Secrets do not match, please try again',
	   5 => 'Alpha-Numeric input is allowed only',
	   6 => 'Invalid Number as Input'
	   );


if (param) {
    if (param('action') eq 'Update') {
	my $err = 0;
	foreach(keys %conf_html) { $conf_html{$_} = param($_); }
	foreach(keys %conf) { $conf{$_} = param($_); }
	foreach(keys %conf_ap) { $conf_ap{$_} = param($_); }
	
	if (!st_number($conf_html{$confz})) {
	    $conf_html{'info'} = $msg{6};
	    $err++;
	}
	
	if (!st_ip($conf_html{$confi})) {
	    $conf_html{'info'} = $msg{3};
	    $err++;
	}
	if ($conf_html{$confn} ne $conf_html{$confr}) {
	    $conf_html{'info'} = $msg{4};
	    $err++;
	}
	
	foreach(keys %conf_html) { 
	    if (st_bad_char($conf_html{$_})) {
		$conf_html{'info'} = $msg{5};
		$err++;
	    }
	}
	
	if ($err) {
	    st_output2($mainpage,\%conf_html);
	    rs();
	} else {
	    $conf_html{'info'} = $msg{1};
	    st_write_config($config_file,\%conf);
	    st_write_config($secureap_file,\%conf_ap);
	    st_restart_hostapd();
	}
    }

}    

if ($state) {
    my $config_content = st_get_html($config_file);
    $config_content =~ s/\#+.*\n/\n/g; # delete comments
    my $blank = '[[:blank:]]*';
    my $noblank = '([^\s]+)';
    my $newl = '\n';
    
    my $expr = 
	$confc.$blank.'='.$blank.$noblank.$blank.$newl.
	$blank.$confs.$blank.'='.$blank.$noblank.$blank.$newl.
	$blank.$confn.$blank.'='.$blank.$noblank.$blank.$newl;
    if ($config_content =~ /$expr/)  {
	#$conf_html{$confc} = $1;
	#$conf_html{$confs} = $2;
	$conf_html{$confn} = $3;
	$conf_html{$confr} = $3;
    }
    $config_content = st_get_html($config_file);
    $expr = $confz.$blank.'='.$blank.$noblank.$blank.$newl;
    if ($config_content =~ /$expr/)  {
	$conf_html{$confz} = $1;
    }
    
    $conf_html{$confi} = st_get_auth_ip();
    st_output2($mainpage,\%conf_html);
}
