#!/usr/bin/perl

use CGI qw/:standard/;
require '../web-lib.pl';
require './wireless-lib.pl';

&ReadParse();
&header($text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("802.11", "man", "doc"));
print "<hr>\n";

my $state = 1;
my $mainpage = "wpa.html";
my $config_file = st_get_conf('hostapd_conf');
sub rs { $state = 0; }

my %config_pars	= st_get_config($config_file);

my %conf = ("ssid" => $config_pars{'ssid'},
	    "wep_rekey_period" => $config_pars{wep_rekey_period});

my @num = ("wep_rekey_period");

my %msg = (1 => 'Invalid Number as Input',
	   2 => 'New Parameters are updated now'
	   );

my $script_action = $in{action};
# print "action = $script_action"; return;

    if ($script_action eq 'Submit') 
    {
	my $err = 0;
	my %new = ();
	foreach(keys %conf) {  $new{$_} = $in{$_}; }

	foreach(@num) {
	    if (!st_number($new{$_})){
		$new{'info'} = $msg{1};
		$err++;
	    }
	}
	
	if ($err) {
	    st_output2($mainpage,\%new);    
	    rs();
	} else {

	    # st_write_config($config_file,\%new);
	    $conf{'info'} = $msg{2};
	    st_output2($mainpage,\%conf);    
	    rs();
	    st_restart_hostapd();
	}
    }

if ($state) {  st_output2($mainpage,\%conf); }

print "<hr>\n";
&footer("/", $text{'index'});

