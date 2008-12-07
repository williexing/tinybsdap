#!/usr/bin/perl
# run-postinstalls.pl
# Run all the postinstall.pl scripts in module directories

$no_acl_check++;
do './web-lib.pl';
&init_config();

if (@ARGV > 0) {
	@mods = map { local %minfo = &get_module_info($_); \%minfo } @ARGV;
	}
else {
	@mods = &get_all_module_infos();
	}

foreach $m (@mods) {
	if (&check_os_support($m) &&
	    -r "$root_directory/$m->{'dir'}/postinstall.pl") {
		# Call this module's postinstall function
		eval {
			&foreign_require($m->{'dir'}, "postinstall.pl");
			&foreign_call($m->{'dir'}, "module_install");
			};
		}
	}

