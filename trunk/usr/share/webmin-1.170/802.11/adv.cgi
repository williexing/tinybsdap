#!/usr/bin/perl

use CGI qw/:standard :cgi-lib/;
do '../../web-lib.pl';
require './st_lib.pl';

my $mainpage = "adv.html";
my $state = 1;

sub rs { $state = 0; }

my %out = ('info' => '');
my %infos = (1 => "Shutting down ...",
	     2 => "Resetting Server ...",
	     3 => "Secure Mode is turned on now",
	     4 => "Secure Mode is turned off now",
	     5 => "Admin Password is changed now",
	     6 => "An Error occured while trying to change Admin Password, ".
	     'please try again',
	     7 => "The Passwords typed in do not match, please try again.");

if (param) {
    if (param('action') eq 'Cancel') {
	st_output($mainpage);
	rs();
    }
    
    if (param('action') eq "Shutdown") {					    
	if (param('step') eq '1') { st_output("adv_shutdown.html"); rs();}
	if (param('step') eq '2') {
	    $out{'info'} = $infos{1};
	    st_output2($mainpage,\%out);
	    rs();
	    st_shutdown();
	}
	
    }

    if (param('action') eq 'Reset') {
	if (param('step') eq '1') { st_output("adv_reset.html"); rs();}
	if (param('step') eq '2') { 
	    $out{'info'} = $infos{2};
	    st_output2($mainpage,\%out);
	    st_reset();
	    rs();
	}
    }

    if (param('action') eq "Secmodeon") {
	
	if (param('step') eq '1') { st_output("adv_secmode_on.html"); rs();}
	if (param('step') eq '2') {
	    $out{'info'} = $infos{3};
	    st_output2($mainpage,\%out);
	    rs();
	    st_secmode_on();
	}
	
    }
    if (param('action') eq "Secmodeoff") {
	if (param('step') eq '1') { st_output("adv_secmode_off.html"); rs();}
	if (param('step') eq '2') {
	    $out{'info'} = $infos{4};
	    st_output2($mainpage,\%out);
	    rs();
	    st_secmode_off();
	}
	
    }
    
    if (param('action') eq 'Passwd') {
	my $page = 'adv_passwd.html';
	my %out = ('info' => '','PASS1' => '','PASS2' => '');
	if (param('step') eq '1') { st_output2($page,\%out); rs();}
	if (param('step') eq '2') {
	    my $pass1 = param('pass1');
	    my $pass2 = param('pass2');
	    if ($pass1 eq $pass2) {
		if (st_set_admin_pass("$pass1")) {
		    $out{'info'} = $infos{5};
		    st_output2($mainpage,\%out);
		    rs();
		} else {
		    $out{'PASS1'} = $pass1;
		    $out{'PASS2'} = $pass2;
		    $out{'info'} = $infos{6};
		    
		    st_output2($page,\%out);
		    rs();
		}
	    } else {
		$out{'info'} = $infos{7};
		st_output2($page,\%out);
		rs();
	    }
	}
	
    }

} 

if($state) { st_output($mainpage); }
