#!/usr/local/bin/perl
# change_ui.cgi
# Change colour scheme

require './webmin-lib.pl';
&error_setup($text{'ui_err'});
&ReadParse();

&lock_file("$config_directory/config");
for($i=0; $i<@cs_names; $i++) {
	$cd = $cs_codes[$i];
	if ($in{"${cd}_def"}) { delete($gconfig{$cd}); }
	elsif ($in{"${cd}_rgb"} !~ /^[0-9a-fA-F]{6}$/) {
		&error(&text('ui_ergb', $cs_names[$i]));
		}
	else { $gconfig{$cd} = $in{"${cd}_rgb"}; }
	}

$gconfig{'texttitles'} = $in{'texttitles'};
$gconfig{'sysinfo'} = $in{'sysinfo'};
$gconfig{'hostnamemode'} = $in{'hostnamemode'};
$gconfig{'hostnamedisplay'} = $in{'hostnamedisplay'};
$gconfig{'feedback_to'} = $in{'feedback_def'} ? undef : $in{'feedback'};
$gconfig{'nofeedbackcc'} = $in{'nofeedbackcc'};
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log('ui', undef, undef, \%in);
&redirect("");

