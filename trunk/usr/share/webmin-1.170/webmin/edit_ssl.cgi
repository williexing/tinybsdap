#!/usr/local/bin/perl
# edit_ssl.cgi
# Webserver SSL form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'ssl_title'}, "");
&get_miniserv_config(\%miniserv);

eval "use Net::SSLeay";
if ($@) {
	print &text('ssl_essl', "http://www.webmin.com/ssl.html"),"<p>\n";
	&read_acl(\%acl, undef);
	if ($acl{$base_remote_user, 'cpan'}) {
		print &text('ssl_cpan', "/cpan/download.cgi?source=3&cpan=Net::SSLeay&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"<p>\n";
		}
	$err = $@;
	$err =~ s/\s+at.*line\s+\d+[\000-\377]*$//;
	print &text('ssl_emessage', "<tt>$err</tt>"),"<p>\n";
	}
else {
	print $text{'ssl_desc1'},"<p>\n";
	print $text{'ssl_desc2'},"<p>\n";

	print "<form action=change_ssl.cgi>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'ssl_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$text{'ssl_on'}</b></td>\n";
	printf "<td><input type=radio name=ssl value=1 %s> %s\n",
		$miniserv{'ssl'} ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=ssl value=0 %s> %s</td> </tr>\n",
		$miniserv{'ssl'} ? "" : "checked", $text{'no'};

	print "<tr> <td><b>$text{'ssl_key'}</b></td>\n";
	printf "<td><input name=key size=40 value='%s'> %s</td> </tr>\n",
		$miniserv{'keyfile'}, &file_chooser_button("key");

	print "<tr> <td valign=top><b>$text{'ssl_cert'}</b></td>\n";
	printf "<td><input type=radio name=cert_def value=1 %s> %s<br>\n",
		$miniserv{'certfile'} ? "" : "checked", $text{'ssl_cert_def'};
	printf "<input type=radio name=cert_def value=0 %s> %s\n",
		$miniserv{'certfile'} ? "checked" : "", $text{'ssl_cert_oth'};
	printf "<input name=cert size=40 value='%s'> %s</td> </tr>\n",
		$miniserv{'certfile'}, &file_chooser_button("cert");

	print "<tr> <td><b>$text{'ssl_redirect'}</b></td>\n";
	printf "<td><input type=radio name=ssl_redirect value=1 %s> %s\n",
		$miniserv{'ssl_redirect'} ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=ssl_redirect value=0 %s> %s</td></tr>\n",
		$miniserv{'ssl_redirect'} ? "" : "checked", $text{'no'};

	print "<tr> <td valign=top><b>$text{'ssl_extracas'}</b></td>\n";
	print "<td><textarea name=extracas rows=3 cols=40>";
	foreach $e (split(/\s+/, $miniserv{'extracas'})) {
		print "$e\n";
		}
	print "</textarea></td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value=\"$text{'save'}\"></form>\n";

	print "<hr>\n";

	print "$text{'ssl_newkey'}\n";
	local $curkey = `cat $miniserv{'keyfile'} 2>/dev/null`;
	local $origkey = `cat $root_directory/miniserv.pem 2>/dev/null`;
	if ($curkey eq $origkey) {
		# System is using the original (insecure) Webmin key!
		print "<b>$text{'ssl_hole'}</b>\n";
		}
	print "<p>\n";

	print "<form action=newkey.cgi>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'ssl_header1'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";
	print "<tr> <td><b>$text{'ssl_cn'}</b></td>\n";
	print "<td><input type=radio name=commonName_def value=1 checked> ",
	      "$text{'ssl_all'}\n";
	print "<input type=radio name=commonName_def value=0>\n";
	$host = $ENV{'HTTP_HOST'};
	$host =~ s/:.*//;
	print "<input name=commonName size=30 value='$host'></td> </tr>\n";

	print "<tr> <td><b>$text{'ca_email'}</b></td>\n";
	printf "<td><input name=emailAddress size=30 value='%s'></td> </tr>\n",
		"webmin\@".&get_system_hostname();

	print "<tr> <td><b>$text{'ca_ou'}</b></td>\n";
	print "<td><input name=organizationalUnitName size=30></td> </tr>\n";

	$hostname = &get_system_hostname();
	print "<tr> <td><b>$text{'ca_o'}</b></td>\n";
	print "<td><input name=organizationName size=30 ",
	      "value='Webmin Webserver on $hostname'></td> </tr>\n";

	print "<tr> <td><b>$text{'ca_sp'}</b></td>\n";
	print "<td><input name=stateOrProvinceName size=15></td> </tr>\n";

	print "<tr> <td><b>$text{'ca_c'}</b></td>\n";
	print "<td><input name=countryName size=2></td> </tr>\n";

	print "<tr> <td><b>$text{'ssl_size'}</b></td>\n";
	print "<td><input type=radio name=size_def value=1 checked> ",
	      "$text{'default'} ($default_key_size)\n";
	print "<input type=radio name=size_def value=0> ",
	      "$text{'ssl_custom'}\n";
	print "<input name=size size=6> $text{'ssl_bits'}</td> </tr>\n";

	print "<tr> <td><b>$text{'ssl_days'}</b></td>\n";
	print "<td><input name=days size=8 value='1825'></td> </tr>\n";

	print "<tr> <td><b>$text{'ssl_newfile'}</b></td>\n";
	printf "<td><input name=newfile size=40 value='%s'></td> </tr>\n",
		"$config_directory/miniserv.pem";

	print "<tr> <td><b>$text{'ssl_usenew'}</b></td> <td>\n";
	print "<input type=radio name=usenew value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=usenew value=0> $text{'no'}</td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'ssl_create'}'></form>\n";
	}

&ui_print_footer("", $text{'index_return'});

