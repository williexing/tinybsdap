#!/usr/bin/perl
do '../web-lib.pl';
&init_config();
require '../ui-lib.pl';
mountrw();
&ReadParse();
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));
system('/bin/ln -s /etc/init.d/ssh /etc/rc2.d/S20ssh');
print "<font color=red><b>System formated!</b></font><p>";
print "Will try to reboot. ";
