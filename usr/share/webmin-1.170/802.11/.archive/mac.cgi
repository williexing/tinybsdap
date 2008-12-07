#!/usr/bin/perl

use CGI qw/:standard :cgi-lib/;
do '../../web-lib.pl';
require './st_lib.pl';

my $mainpage = "mac.html";
my $config_file = st_get_conf('deny_list');
my $state = 1;
sub rs { $state = 0; }

my $conf = 'mac';


my %info = (1 => 'MAC Address is invalid, please try again.',
	    );
my %new = ('MAC' => '','info' => '');

if (param) {
    if (param('action') eq 'Add') { 
	my $mac = param('mac');
	if (!(st_valid_mac($mac))) {
	    $new{'info'} = $info{1};
	} else {
	    st_add2file($config_file,$mac."\n");
	}
    }

    if (param('action') eq 'Delete') { 
	my $content = st_get_html($config_file);
	my $mac = param('delmac');
	$content =~ s/$mac\n//g;
	st_write2file($config_file,$content);
    }
}

if($state) {
    if(st_isFile($config_file)) {
	my $content= st_get_html($config_file);
	my $text = '';
	open IN,$config_file;
	while (<IN>) {
	    if (st_valid_mac($_)) {
		$text = 
		    $text.
		    "<form action=mac.cgi method=post>".
		    "<tr><td>$_</td><td>".
		    "<input type=submit name=action value=\"Delete\">".
		    "<input type=hidden name=\"delmac\" value=\"$_\">".
		    "</td></tr></form>\n";
	    }
	}
	close IN;
	$new{'MAC'} = $text;
    }
    st_output2($mainpage,\%new);
}
