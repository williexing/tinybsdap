#!/usr/bin/perl
# list_routes.cgi
# List boot-time routing configuration

require './net-lib.pl';
$access{'routes'} || &error($text{'routes_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'routes_title'}, "");

print "<form action=save_routes.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>",
      $routes_active_now? $text{'routes_now'} : $text{'routes_boot'},
      "</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
&routing_input();
print "</table></td></tr></table>\n";
printf "<input type=submit value=\"%s\">\n",
    ($routes_active_now?  $text{'bifc_apply'} : $text{'save'})
	if ($access{'routes'} == 2);
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

