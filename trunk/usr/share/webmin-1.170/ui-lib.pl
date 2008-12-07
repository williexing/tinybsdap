# ui-lib.pl
# Common functions for generating HTML for Webmin user interface elements

####################### table generation functions

# ui_table_start(heading, [tabletags], [cols])
# A table with a heading and table inside
sub ui_table_start
{
return &theme_ui_table_start(@_) if (defined(&theme_ui_table_start));
local ($heading, $tabletags, $cols) = @_;
local $rv;
$rv .= "<table border $tabletags>\n";
$rv .= "<tr $tb> <td><b>$heading</b></td> </tr>\n" if (defined($heading));
$rv .= "<tr $cb> <td><table width=100%>\n";
$ui_table_cols = $cols || 4;
$ui_table_pos = 0;
return $rv;
}

# ui_table_end()
# The end of a table started by ui_table_start
sub ui_table_end
{
return &theme_ui_table_end(@_) if (defined(&theme_ui_table_end));
return "</table></td></tr></table>\n";
}

# ui_columns_start(&headings, [width-percent], [noborder], [&tdtags])
# Returns HTML for a multi-column table, with the given headings
sub ui_columns_start
{
return &theme_ui_columns_start(@_) if (defined(&theme_ui_columns_start));
local ($heads, $width, $noborder, $tdtags) = @_;
local $rv;
$rv .= "<table".($noborder ? "" : " border").
		(defined($width) ? " width=$width%" : "").">\n";
$rv .= "<tr $tb>\n";
local $i;
for($i=0; $i<@$heads; $i++) {
	$rv .= "<td ".$tdtags->[$i]."><b>".
	       ($heads->[$i] eq "" ? "<br>" : $heads->[$i])."</b></td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

# ui_columns_row(&columns, &tdtags)
# Returns HTML for a row in a multi-column table
sub ui_columns_row
{
return &theme_ui_columns_row(@_) if (defined(&theme_ui_columns_row));
local ($cols, $tdtags) = @_;
local $rv;
$rv .= "<tr $cb>\n";
local $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i].">".
	       ($cols->[$i] eq "" ? "<br>" : $cols->[$i])."</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

# ui_columns_end()
# Returns HTML to end a table started by ui_columns_start
sub ui_columns_end
{
return &theme_ui_columns_end(@_) if (defined(&theme_ui_columns_end));
return "</table>\n";
}

####################### form generation functions

# ui_form_start(script, method)
# Returns HTML for a form that submits to some script
sub ui_form_start
{
return &theme_ui_form_start(@_) if (defined(&theme_ui_form_start));
local ($script, $method) = @_;
local $rv;
$rv .= "<form action='$script' ".
		($method eq "post" ? "method=post" :
		 $method eq "form-data" ?
			"method=post enctype=multipart/form-data" :
			"method=get").">\n";
return $rv;
}

# ui_form_end([&buttons], [width])
# Returns HTML for the end of a form, optionally with a row of submit buttons
sub ui_form_end
{
return &theme_ui_form_end(@_) if (defined(&theme_ui_form_end));
local ($buttons, $width) = @_;
local $rv;
if ($buttons) {
	$rv .= "<table".($width ? " width=$width" : "")."><tr>\n";
	local $b;
	foreach $b (@$buttons) {
		$rv .= "<td".(!$width ? "" :
			      $b eq $buttons->[0] ? " align=left" :
			      $b eq $buttons->[@$buttons-1] ?
				" align=right" : " align=center").">".
		       "<input type=submit name=\"".&quote_escape($b->[0])."\" ".
		       "value=\"".&quote_escape($b->[1])."\"></td>\n";
		}
	$rv .= "</tr></table>\n";
	}
$rv .= "</form>\n";
return $rv;
}

# ui_textbox(name, value, size)
# Returns HTML for a text input
sub ui_textbox
{
return &theme_ui_textbox(@_) if (defined(&theme_ui_textbox));
local ($name, $value, $size) = @_;
return "<input name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       "size=$size>";
}

# ui_upload(name, size)
# Returns HTML for a file upload input
sub ui_upload
{
return &theme_ui_upload(@_) if (defined(&theme_ui_upload));
local ($name, $size) = @_;
return "<input type=file name=\"".&quote_escape($name)."\" ".
       "size=$size>";
}

# ui_password(name, value, size)
# Returns HTML for a password text input
sub ui_password
{
return &theme_ui_password(@_) if (defined(&theme_ui_password));
local ($name, $value, $size) = @_;
return "<input type=password name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       "size=$size>";
}

# ui_hidden(name, value)
# Returns HTML for a hidden field
sub ui_hidden
{
return &theme_ui_hidden(@_) if (defined(&theme_ui_hidden));
local ($name, $value) = @_;
return "<input type=hidden name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\">";
}

# ui_select(name, value|&values, &options, [size], [multiple])
# Returns HTML for a drop-down menu or multiple selection list
sub ui_select
{
return &theme_ui_select(@_) if (defined(&theme_ui_select));
local ($name, $value, $opts, $size, $multiple) = @_;
local $rv;
$rv .= "<select name=\"".&quote_escape($name)."\"".
       ($size ? " size=$size" : "").
       ($multiple ? " multiple" : "").">\n";
local $o;
local %sel = ref($value) ? ( map { $_, 1 } @$value ) : ( $value, 1 );
foreach $o (@$opts) {
	$rv .= "<option value=\"".&quote_escape($o->[0])."\"".
	       ($sel{$o->[0]} ? " selected" : "").">".
	       ($o->[1] || $o->[0])."\n";
	}
$rv .= "</select>\n";
return $rv;
}

# ui_radio(name, value, &options)
# Returns HTML for a series of radio buttons
sub ui_radio
{
return &theme_ui_radio(@_) if (defined(&theme_ui_radio));
local ($name, $value, $opts) = @_;
local $rv;
local $o;
foreach $o (@$opts) {
	$rv .= "<input type=radio name=\"".&quote_escape($name)."\" ".
               "value=\"".&quote_escape($o->[0])."\"".
	       ($o->[0] eq $value ? " checked" : "")."> ".
	       ($o->[1] || $o->[0])."\n";
	}
return $rv;
}

# ui_checkbox(name, value, label, selected?)
# Returns HTML for a single checkbox
sub ui_checkbox
{
return &theme_ui_checkbox(@_) if (defined(&theme_ui_checkbox));
local ($name, $value, $label, $sel) = @_;
return "<input type=checkbox name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       ($sel ? " checked" : "")."> $label\n";
}

# ui_oneradio(name, value, label, selected?)
# Returns HTML for a single radio button
sub ui_oneradio
{
return &theme_ui_oneradio(@_) if (defined(&theme_ui_oneradio));
local ($name, $value, $label, $sel) = @_;
return "<input type=radio name=\"".&quote_escape($name)."\" ".
       "value=\"".&quote_escape($value)."\" ".
       ($sel ? " checked" : "")."> $label\n";
}

# ui_textarea(name, value, rows, cols, [wrap])
# Returns HTML for a multi-line text input
sub ui_textarea
{
return &theme_ui_textarea(@_) if (defined(&theme_ui_textarea));
local ($name, $value, $rows, $cols, $wrap) = @_;
return "<textarea name=\"".&quote_escape($name)."\" ".
       "rows=$rows cols=$cols".($wrap ? " wrap=$wrap" : "").">".
       &html_escape($value).
       "</textarea>";
}

# ui_user_textbox(name, value, [form])
# Returns HTML for a Unix user input
sub ui_user_textbox
{
return &theme_ui_user_textbox(@_) if (defined(&theme_ui_user_textbox));
return &unix_user_input($_[0], $_[1], $_[2]);
}

# ui_group_textbox(name, value, [form])
# Returns HTML for a Unix group input
sub ui_group_textbox
{
return &theme_ui_group_textbox(@_) if (defined(&theme_ui_group_textbox));
return &unix_group_input($_[0], $_[1], $_[2]);
}

# ui_opt_textbox(name, value, size, option1, [option2])
# Returns HTML for a text field that is optional
sub ui_opt_textbox
{
return &theme_ui_opt_textbox(@_) if (defined(&theme_ui_opt_textbox));
local ($name, $value, $size, $opt1, $opt2) = @_;
local $rv;
$rv .= "<input type=radio name=\"".&quote_escape($name."_def")."\" ".
       "value=1 ".($value ne '' ? "" : "checked")."> ".$opt1."\n";
$rv .= "<input type=radio name=\"".&quote_escape($name."_def")."\" ".
       "value=0 ".($value ne '' ? "checked" : "")."> ".$opt2."\n";
$rv .= "<input name=\"".&quote_escape($name)."\" ".
       "size=$size value=\"".&quote_escape($value)."\">\n";
return $rv;
}

# ui_submit(label, [name])
# Returns HTML for a form submit button
sub ui_submit
{
return &theme_ui_submit(@_) if (defined(&theme_ui_submit));
local ($label, $name) = @_;
return "<input type=submit".
       ($name ne '' ? " name=\"".&quote_escape($name)."\"" : "").
       " value=\"".&quote_escape($label)."\">\n";
			
}

# ui_reset(label)
# Returns HTML for a form reset button
sub ui_reset
{
return &theme_ui_reset(@_) if (defined(&theme_ui_reset));
local ($label) = @_;
return "<input type=submit value=\"".&quote_escape($label)."\">\n";
			
}

# ui_table_row(label, value, [cols], [&td-tags])
# Returns HTML for a row in a table started by ui_table_start, with a 1-column
# label and 1+ column value.
sub ui_table_row
{
return &theme_ui_table_row(@_) if (defined(&theme_ui_table_row));
local ($label, $value, $cols) = @_;
$cols ||= 1;
local $rv;
$rv .= "<tr>\n" if ($ui_table_pos%$ui_table_cols == 0);
$rv .= "<td valign=top $_[3]->[0]><b>$label</b></td>\n" if (defined($label));
$rv .= "<td valign=top colspan=$cols $_[3]->[1]>$value</td>\n";
$ui_table_pos += $cols+(defined($label) ? 1 : 0);
$rv .= "</tr>\n" if ($ui_table_pos%$ui_table_cols == 0);
return $rv;
}

# ui_table_hr()
sub ui_table_hr
{
return &theme_ui_table_hr(@_) if (defined(&theme_ui_table_hr));
$ui_table_pos = 0;
return "<tr> <td colspan=$ui_table_cols><hr></td> </tr>\n";
}

# ui_buttons_start()
sub ui_buttons_start
{
return &theme_ui_buttons_start(@_) if (defined(&theme_ui_buttons_start));
return "<table width=100%>\n";
}

# ui_buttons_end()
sub ui_buttons_end
{
return &theme_(@_) if (defined(&theme_));
return "</table>\n";
}

# ui_buttons_row(script, button-label, description, [hiddens], [after-submit]) 
sub ui_buttons_row
{
return &theme_ui_buttons_row(@_) if (defined(&theme_ui_buttons_row));
local ($script, $label, $desc, $hiddens, $after) = @_;
return "<form action=$script>\n".
       $hiddens.
       "<tr> <td nowrap><input type=submit value='$label'> $after</td>\n".
       "<td valign=top>$desc</td> </tr>\n".
       "</form>\n";
}


####################### header and footer functions

# ui_post_header([subtext])
# Returns HTML to appear directly after a standard header() call
sub ui_post_header
{
return &theme_ui_post_header(@_) if (defined(&theme_ui_post_header));
local ($text) = @_;
local $rv;
$rv .= "<center><font size=+1>$text</font></center>\n" if (defined($text));
$rv .= "<hr>\n";
return $rv;
}

# ui_pre_footer()
# Returns HTML to appear directly before a standard footer() call
sub ui_pre_footer
{
return &theme_ui_pre_footer(@_) if (defined(&theme_ui_pre_footer));
return "<hr>\n";
}

# ui_print_header(subtext, args...)
# Print HTML for a header with the post-header line. The args are the same
# as those passed to header()
sub ui_print_header
{
&load_theme_library();
return &theme_ui_print_header(@_) if (defined(&theme_ui_print_header));
local ($text, @args) = @_;
&header(@args);
print &ui_post_header($text);
}

# ui_print_unbuffered_header(subtext, args...)
# Like ui_print_header, but ensures that output for this page is not buffered
# or contained in a table.
sub ui_print_unbuffered_header
{
&load_theme_library();
return &theme_ui_print_unbuffered_header(@_) if (defined(&theme_ui_print_unbuffered_header));
$| = 1;
$theme_no_table = 1;
&ui_print_header(@_);
}

# ui_print_footer(args...)
# Print HTML for a footer with the pre-footer line. Args are the same as those
# passed to footer()
sub ui_print_footer
{
return &theme_ui_print_footer(@_) if (defined(&theme_ui_print_footer));
local @args = @_;
print &ui_pre_footer();
&footer(@args);
}

# ui_config_link(text, &subs)
# Returns HTML for a module config link. The first non-null sub will be
# replaced with the appropriate URL.
sub ui_config_link
{
return &theme_ui_config_link(@_) if (defined(&theme_ui_config_link));
local ($text, $subs) = @_;
local @subs = map { $_ || "../config.cgi?$module_name" }
		  ($subs ? @$subs : ( undef ));
return "<p>".&text($text, @subs)."<p>\n";
}

# ui_print_endpage(text)
# Prints HTML for an error message followed by a page footer with a link to
# /, then exits. Good for main page error messages.
sub ui_print_endpage
{
return &theme_ui_print_endpage(@_) if (defined(&theme_ui_print_endpage));
local ($text) = @_;
print $text,"<p>\n";
&ui_print_footer("/", $text{'index'});
exit;
}

1;

