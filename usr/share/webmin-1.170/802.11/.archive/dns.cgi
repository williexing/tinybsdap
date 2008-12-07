#!/usr/bin/perl

use CGI qw/:standard :cgi-lib/;
do '../../web-lib.pl';
require './st_lib.pl';

my $mainpage = "dns.html";
my @conf=('login','password','repass','domain','dns');
my $conf_dns = 'dns';
my $dns = 0;

my $state = 1;
sub rs { $state = 0; }

my %info = (1 => 'DynDNS is turned on now.',
	    2 => 'An Error occured while trying to load DynDNS,'.
	    ' please try again.',
	    3 => 'Error: Login, Password and Domain Information are mandatory.',
	    4 => 'Error: Please try again without special Characters.',
	    5 => 'Password and Retyped Password do not match, please try again.',
	    6 => 'DynDNS is turned off now.',
	    );

my %new = ();
foreach(@conf) { $new{$_} = ''; }
$new{'info'} = '';

if (param) {
    if (param('action') eq 'Update DynDNS') { 
	my $err = 0;

	if(param($conf_dns) eq 'checked') { $dns = 1; }
	
	if ($dns) {  
	    foreach(@conf) { $new{$_} = param($_); }

	    foreach(@conf) { 
		if (st_bad_char($new{$_})) {
		    $new{'info'} = $info{4};
		    $err++;
		}
		if (($new{$_} eq '')) {
		    $new{'info'} = $info{3};
		    $err++;
		}
	    }
	    if ($new{'password'} ne $new{'repass'}) {
		$new{'repass'} = '';
		$new{'password'} = '';
		$new{'info'} = $info{5};
		$err++;
	    }
	}
	
	if ($dns) {
	    if ($err) {
		st_output2($mainpage,\%new);
		rs();
	    } else {
		st_dns_start($new{'login'},$new{'password'},$new{'domain'});
		$new{'info'} = $info{1};
	    }
	} else {
	    st_dns_stop();
	    $new{'info'} = $info{6};
	}
    }
}

if($state) {
    foreach(@conf) { $new{$_} = ''; }

    if(st_is_dns()) {
	($login,$pass,$domain) = st_get_dns();
	$new{'login'} = $login;
	$new{'password'} = $pass;
	$new{'repass'} = $pass;
	$new{'domain'} = $domain;
	$new{'dns'} = 'checked';
    } 
    st_output2($mainpage,\%new);
}

