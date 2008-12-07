#!/usr/bin/perl
# run-uninstalls.pl
# Run all the uninstall.pl scripts in module directories

$no_acl_check++;
do './web-lib.pl';
&init_config();

foreach $m (&get_all_module_infos()) {
	if (&check_os_support($m) &&
	    -r "$root_directory/$m->{'dir'}/uninstall.pl") {
		# Call this module's uninstall function
		eval {
			&foreign_require($m->{'dir'}, "uninstall.pl");
			&foreign_call($m->{'dir'}, "module_uninstall");
			};
		}
	}

