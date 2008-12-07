#!/usr/bin/perl
# save_local.cgi
# Save the local startup script

require './init-lib.pl';
%access = &get_module_acl();
$access{'bootup'} == 1 || &error("You are not allowed to edit the bootup script");
&ReadParse();
$in{'local'} =~ s/\r//g;
&lock_file($config{'local_script'});
open(LOCAL, "> $config{'local_script'}");
print LOCAL $in{'local'};
close(LOCAL);
&unlock_file($config{'local_script'});
if ($config{'local_down'}) {
	$in{'down'} =~ s/\r//g;
	&lock_file($config{'local_down'});
	open(LOCAL, "> $config{'local_down'}");
	print LOCAL $in{'down'};
	close(LOCAL);
	&unlock_file($config{'local_down'});
	}
&webmin_log("local", undef, undef, \%in);
&redirect("");

