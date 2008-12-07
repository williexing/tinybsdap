#!/usr/local/bin/perl
# many_form.cgi
# Display a form for creating many users from a text file

require './user-lib.pl';
&ui_print_header(undef, $text{'many_title'}, "");

print "<p>$text{'many_desc'}\n";
if (&passfiles_type() == 1) {
	print "<p><tt>$text{'many_desc1'}</tt><p>\n";
	}
elsif (&passfiles_type() == 2) {
	print "<p><tt>$text{'many_desc2'}</tt><p>\n";
	}
else {
	print "<p><tt>$text{'many_desc0'}</tt><p>\n";
	}
print "$text{'many_descafter'}\n";
print "$text{'many_descpass'}<p>\n";

print "<form action=many_create.cgi method=post enctype=multipart/form-data>\n";
print "<table>\n";
print "<tr> <td><b>$text{'many_file'}</b></td>\n";
print "<td><input type=file name=file></td> </tr>\n";

print "<tr> <td><b>$text{'many_local'}</b></td>\n";
print "<td><input name=local size=30> ",&file_chooser_button("local"),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'many_makehome'}</b></td>\n";
print "<td><input name=makehome type=radio value=1 checked> $text{'yes'}\n";
print "<input name=makehome type=radio value=0> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'many_copy'}</b></td>\n";
print "<td><input name=copy type=radio value=1 checked> $text{'yes'}\n";
print "<input name=copy type=radio value=0> $text{'no'}</td> </tr>\n";

print "<tr> <td><input type=submit value=\"$text{'many_upload'}\"></td> </tr>\n";
print "</table></form>\n";

&ui_print_footer("", $text{'index_return'});

