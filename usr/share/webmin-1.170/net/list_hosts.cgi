#!/usr/bin/perl
# list_hosts.cgi
# List hosts from /etc/hosts

require './net-lib.pl';
$access{'hosts'} || &error($text{'hosts_ecannot'});
&ui_print_header(undef, $text{'hosts_title'}, "");

print "<a href=\"edit_host.cgi?new=1\">$text{'hosts_add'}</a><br>\n"
	if ($access{'hosts'} == 2);
print "<table border cellpadding=3>\n";
print "<tr $tb> <td><b>$text{'hosts_ip'}</b></td> ",
      "<td><b>$text{'hosts_host'}</b></td> </tr>\n";
foreach $h (&list_hosts()) {
	print "<tr $cb>\n";
	if ($access{'hosts'} == 2) {
		print "<td><a href=\"edit_host.cgi?idx=$h->{'index'}\">",
		      &html_escape($h->{'address'}),"</a></td>\n";
		}
	else {
		print "<td>",&html_escape($h->{'address'}),"</td>\n";
		}
	print "<td>",join("&nbsp;&nbsp; ", map { &html_escape($_) }
					   @{$h->{'hosts'}}),"</td> </tr>\n";
	}
print "</table>\n";
print "<a href=\"edit_host.cgi?new=1\">$text{'hosts_add'}</a>\n"
	if ($access{'hosts'} == 2);
print "<p>\n";

&ui_print_footer("", $text{'index_return'});

