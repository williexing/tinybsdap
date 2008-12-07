#!/usr/bin/perl
# config.cgi
# Display a form for editing the configuration of a module.

require './web-lib.pl';
require './config-lib.pl';
require './ui-lib.pl';
&init_config();
$m = $ARGV[0];
&read_acl(\%acl);
$acl{$base_remote_user,$m} || &error($text{'config_eaccess'});
%access = &get_module_acl(undef, $m);
$access{'noconfig'} &&
	&error($text{'config_ecannot'});
%module_info = &get_module_info($m);
&ui_print_header(&text('config_dir', $module_info{'desc'}),
		 $text{'config_title'}, "", undef, 0, 1);

print "<form action=\"config_save.cgi\" method=post>\n";
print "<input type=hidden name=module value=\"$m\">\n";
print "<table border>\n";
print "<tr $tb> <td><b>",&text('config_header', $module_info{'desc'}),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
&read_file("$config_directory/$m/config", \%config);

if (-r "$m/config_info.pl") {
	# Module has a custom config editor
	&foreign_require($m, "config_info.pl");
	local $fn = "${m}::config_form";
	if (defined(&$fn)) {
		$func++;
		&foreign_call($m, "config_form", \%config);
		}
	}
if (!$func) {
	# Use config.info to create config inputs
	&generate_config(\%config, "$root_directory/$m/config.info", $m);
	}
print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("/$m", $text{'index'});

