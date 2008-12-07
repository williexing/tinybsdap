#!/usr/bin/perl
# delboot.pl
# Called by uninstall.sh to stop webmin being started at boot time

$no_acl_check++;
require './init-lib.pl';
if ($config{'darwin_setup'}) {
	# Remove from hostconfig file
	open(LOCAL, $config{'hostconfig'});
	@local = <LOCAL>;
	close(LOCAL);
	$start = "WEBMIN=-";
	open(LOCAL, ">$config{'hostconfig'}");
	print LOCAL grep { !/^$start/ } @local;
	close(LOCAL);
	print "Deleted from $config{'hostconfig'}\n";
	# get rid of the startup items
	$paramlist = "$config{'darwin_setup'}/Webmin/$config{'plist'}";
	$scriptfile = "$config{'darwin_setup'}/Webmin/Webmin";
	print "Deleting $config{'darwin_setup'}/Webmin ..";
	unlink ($paramlist);
	unlink ($scriptfile);
	print "\. ", rmdir ("$config{'darwin_setup'}/Webmin") ? "Success":"Failed", "\n";
	}
elsif (!$config{'init_base'}) {
	# Remove from boot time rc script
	open(LOCAL, $config{'local_script'});
	@local = <LOCAL>;
	close(LOCAL);
	$start = "$config_directory/start";
	open(LOCAL, ">$config{'local_script'}");
	print LOCAL grep { !/^$start/ } @local;
	close(LOCAL);
	print "Deleted from bootup script $config{'local_script'}\n";
	}
else {
	# Delete bootup action
	foreach (&action_levels('S', "webmin")) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		&delete_rl_action("webmin", $1, 'S');
		}
	foreach (&action_levels('K', "webmin")) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		&delete_rl_action("webmin", $1, 'K');
		}
	$fn = &action_filename("webmin");
	unlink($fn);
	print "Deleted init script $fn\n";
	}

