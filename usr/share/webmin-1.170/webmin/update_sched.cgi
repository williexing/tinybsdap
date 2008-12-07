#!/usr/local/bin/perl
# update_sched.cgi
# Schedule the auto-updating of webmin modules

require './webmin-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'update_err'});

# Validate inputs
&lock_file("$module_config_directory/config");
if ($in{'source'} == 0) {
	$config{'upsource'} = undef;
	}
else {
	$in{'other'} =~ /^http:\/\/([^:\/]+)(:(\d+))?(\/\S+)$/ ||
		&error($text{'update_eurl'});
	$config{'upsource'} = $in{'other'};
	}
$config{'update'} = $in{'enabled'};
$in{'hour'} =~ /^\d+$/ && $in{'hour'} < 24 ||
	&error($text{'update_ehour'});
$config{'uphour'} = $in{'hour'};
$in{'mins'} =~ /^\d+$/ && $in{'mins'} < 60 ||
	&error($text{'update_emins'});
$config{'upmins'} = $in{'mins'};
$in{'days'} =~ /^\d+$/ ||
	&error($text{'update_edays'});
$config{'updays'} = $in{'days'};
$config{'upshow'} = $in{'show'};
$config{'upmissing'} = $in{'missing'};
$config{'upthird'} = $in{'third'};
$config{'upquiet'} = $in{'quiet'};
$config{'upemail'} = $in{'email'};
!$in{'show'} || $in{'email'} || &error($text{'update_eemail'});
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");

# Setup the cron job
$cron_cmd = "$module_config_directory/update.pl";
&lock_file($cron_cmd);
foreach $j (&foreign_call("cron", "list_cron_jobs")) {
	$job = $j if ($j->{'user'} eq 'root' && $j->{'command'} eq $cron_cmd);
	}
if ($job) {
	&foreign_call("cron", "delete_cron_job", $job);
	unlink($cron_cmd);
	}
if ($in{'enabled'}) {
	# Create the program that cron calls
	&cron::create_wrapper($cron_cmd, $module_name, "update.pl");

	# Setup the actual cron job
	if ($in{'days'} == 1) {
		@days = ( "*" );
		}
	else {
		for($i=1; $i<=31; $i+=$in{'days'}) {
			push(@days, $i);
			}
		}
	$njob = { 'user' => 'root', 'active' => 1, 'mins' => $in{'mins'},
		  'hours' => $in{'hour'}, 'days' => join(",",@days),
		  'months' => '*', 'weekdays' => '*',
		  'command' => $cron_cmd };
	&foreign_call("cron", "create_cron_job", $njob);
	}
&unlock_file($cron_cmd);
&redirect("");


