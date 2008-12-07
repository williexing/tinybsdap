#!/usr/local/bin/perl
# edit_lang.cgi
# Language config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'lang_title'}, "");

print $text{'lang_intro'},"<p>\n";

print "<form action=change_lang.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'lang_title2'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

$clang = $gconfig{'lang'} ? $gconfig{'lang'} : $default_lang;
print "<tr> <td><b>$text{'lang_lang'}</b></td>\n";
print "<td><select name=lang>\n";
foreach $l (&list_languages()) {
	printf "<option value=%s %s>%s (%s)\n",
		$l->{'lang'},
		$clang eq $l->{'lang'} ? 'selected' : '',
		$l->{'desc'}, uc($l->{'lang'});
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'lang_charset'}</b></td>\n";
printf "<td><input type=radio name=charset_def value=1 %s> %s\n",
	$gconfig{'charset'} ? "" : "checked", $text{'lang_chardef'};
printf "<input type=radio name=charset_def value=0 %s>\n",
	$gconfig{'charset'} ? "checked" : "";
printf "<input name=charset size=15 value='%s'></td> </tr>\n",
	$gconfig{'charset'};

print "<tr> <td><b>$text{'lang_accept'}</b></td>\n";
printf "<td><input type=radio name=acceptlang value=1 %s> %s\n",
	$gconfig{'acceptlang'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=acceptlang value=0 %s> %s</td> </tr>\n",
	$gconfig{'acceptlang'} ? "" : "checked", $text{'no'};

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'lang_ok'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

