#!/usr/bin/perl
# index.cgi
# Display current iptables firewall configuration from save file

require './secureap-lib.pl';
require '../web-lib.pl';

&ReadParse();
&header($text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));
print "<hr>\n";

print "<p><a href=wpa.cgi>WiFi Protected Access (WPA)</a>";
print "<p><a href=mac.cgi>MAC Level Control List</a>";
print "<p><a href=auth.cgi>Authentication Server</a>";
print "<p><a href=adv.cgi>Advanced Settings</a>";

print "<hr>\n";
&footer("/", $text{'index'});

