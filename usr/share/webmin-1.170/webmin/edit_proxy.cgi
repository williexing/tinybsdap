#!/usr/local/bin/perl
# edit_proxy.cgi
# Proxy servers config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'proxy_title'}, "");

print $text{'proxy_desc'},"\n";

print "<form action=change_proxy.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'proxy_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td nowrap><b>$text{'proxy_http'}</b></td>\n";
printf "<td nowrap><input type=radio name=http_def value=1 %s> %s\n",
	$gconfig{'http_proxy'} ? "" : "checked", $text{'proxy_none'};
printf "<input type=radio name=http_def value=0 %s> \n",
	$gconfig{'http_proxy'} ? "checked" : "";
printf "<input name=http size=35 value=\"%s\"></td> </tr>\n",
	$gconfig{'http_proxy'};

print "<tr> <td nowrap><b>$text{'proxy_ftp'}</b></td>\n";
printf "<td nowrap><input type=radio name=ftp_def value=1 %s> %s\n",
	$gconfig{'ftp_proxy'} ? "" : "checked", $text{'proxy_none'};
printf "<input type=radio name=ftp_def value=0 %s> \n",
	$gconfig{'ftp_proxy'} ? "checked" : "";
printf "<input name=ftp size=35 value=\"%s\"></td> </tr>\n",
	$gconfig{'ftp_proxy'};

print "<tr> <td nowrap><b>$text{'proxy_nofor'}</b></td>\n";
printf "<td nowrap><input name=noproxy size=40 value=\"%s\"></td> </tr>\n",
	$gconfig{'noproxy'};

print "<tr> <td nowrap><b>$text{'proxy_user'}</b></td>\n";
printf "<td><input name=user size=20 value='%s'></td> </tr>\n",
	$gconfig{'proxy_user'};
print "<tr> <td nowrap><b>$text{'proxy_pass'}</b></td>\n";
printf "<td><input type=password name=pass size=20 value='%s'></td> </tr>\n",
	$gconfig{'proxy_pass'};

print "<tr> <td nowrap><b>$text{'proxy_bind'}</b></td>\n";
printf "<td nowrap><input type=radio name=bind_def value=1 %s> %s\n",
	$gconfig{'bind_proxy'} ? "" : "checked", $text{'default'};
printf "<input type=radio name=bind_def value=0 %s> \n",
	$gconfig{'bind_proxy'} ? "checked" : "";
printf "<input name=bind size=35 value=\"%s\"></td> </tr>\n",
	$gconfig{'bind_proxy'};

print "</table></td></tr></table><br>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

