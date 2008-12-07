#!/usr/bin/perl
# list_ifcs.cgi
# List active and boot-time interfaces

require './net-lib.pl';
&ReadParse();
$access{'ifcs'} || &error($text{'ifcs_ecannot'});
$allow_add = &can_create_iface() && !$noos_support_add_ifcs;
&ui_print_header(undef, $text{'ifcs_title'}, "");

# Show interfaces that are currently active
print "<h3>$text{'ifcs_now'}</h3>\n";
print "<a href='edit_aifc.cgi?new=1'>$text{'ifcs_add'}</a><br>\n"
	if ($allow_add);
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'ifcs_name'}</b></td> ",
      "<td><b>$text{'ifcs_type'}</b></td> ",
      "<td><b>$text{'ifcs_ip'}</b></td> ",
      "<td><b>$text{'ifcs_mask'}</b></td> ",
      "<td><b>$text{'ifcs_status'}</b></td> </tr>\n";

@act = &active_interfaces();
@act = sort iface_sort @act;
foreach $a (@act) {
	local $mod = &module_for_interface($a);
	local %minfo = $mod ? &get_module_info($mod->{'module'}) : ( );
	print "<tr $cb> <td>";
	if ($a->{'virtual'} ne "") { print "&nbsp;&nbsp;"; }
	if ($a->{'edit'} && &can_iface($a)) {
		print "<a href=\"edit_aifc.cgi?idx=$a->{'index'}\">",
		      &html_escape($a->{'fullname'}),"</a></td>\n";
		}
	elsif (!$a->{'edit'} && $mod) {
		print "<a href=\"mod_aifc.cgi?idx=$a->{'index'}\">",
		      &html_escape($a->{'fullname'}),"</a></td>\n";
		}
	else {
		print &html_escape($a->{'fullname'}),"</td>\n";
		}
	print "<td>",&iface_type($a->{'name'}),
	      ($a->{'virtual'} eq "" ? "" : " ($text{'ifcs_virtual'})"),
	      (%minfo ? " ($minfo{'desc'})" : ""),
	      "</td>\n";
	print "<td>",&html_escape($a->{'address'}),"</td>\n";
	print "<td>",&html_escape($a->{'netmask'}),"</td>\n";
	print "<td>",
		($a->{'up'} ? $text{'ifcs_up'}
			    : "<font color=#ff0000>$text{'ifcs_down'}</font>"),
	      "</td> </tr>\n";
	}
print "</table>\n";
print "<a href='edit_aifc.cgi?new=1'>$text{'ifcs_add'}</a>\n"
	if ($allow_add);
print "<p><hr>\n";

# Show interfaces that get activated at boot
print "<h3>$text{'ifcs_boot'}</h3>\n";
print "<a href='edit_bifc.cgi?new=1'>$text{'ifcs_add'}</a>\n"
	if ($allow_add);
print "<a href='edit_range.cgi?new=1'>$text{'ifcs_radd'}</a>\n"
	if ($allow_add && defined(&supports_ranges) && &supports_ranges());
print "<br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'ifcs_name'}</b></td> ",
      "<td><b>$text{'ifcs_type'}</b></td> ",
      "<td><b>$text{'ifcs_ip'}</b></td> ",
      "<td><b>$text{'ifcs_mask'}</b></td> ",
      "<td><b>$text{'ifcs_act'}</b></td> </tr>\n";

@boot = &boot_interfaces();
@boot = sort iface_sort @boot;
foreach $a (@boot) {
	print "<tr $cb> <td>";
	local $can = $a->{'edit'} && &can_iface($a);
	if ($a->{'range'} ne "") {
		# A range of addresses
		local $rng = &text('ifcs_range', $a->{'range'});
		if ($can) {
			print "<a href=\"edit_range.cgi?idx=$a->{'index'}\">",
			      &html_escape($rng),"</a></td>\n";
			}
		else {
			print &html_escape($rng),"</td>\n";
			}
		print "<td>",&iface_type($a->{'name'}),"</td>\n";
		print "<td colspan=2>$a->{'start'} - $a->{'end'}</td>\n";
		}
	else {
		# A normal single interface
		if ($a->{'virtual'} ne "") { print "&nbsp;&nbsp;"; }
		if ($can) {
			print "<a href=\"edit_bifc.cgi?idx=$a->{'index'}\">",
			      &html_escape($a->{'fullname'}),"</a></td>\n";
			}
		else {
			print &html_escape($a->{'fullname'}),"</td>\n";
			}
		print "<td>",&iface_type($a->{'name'}),
		      ($a->{'virtual'} eq "" ? "" : " ($text{'ifcs_virtual'})"),
		      "</td>\n";
		print "<td>",$a->{'bootp'} ? $text{'ifcs_bootp'} :
			     $a->{'dhcp'} ? $text{'ifcs_dhcp'} :
			     $a->{'address'} ? &html_escape($a->{'address'}) :
					       $text{'ifcs_auto'},
		      "</td>\n";
		print "<td>",$a->{'netmask'} ? &html_escape($a->{'netmask'})
					     : $text{'ifcs_auto'},"</td>\n";
		}
	print "<td>",($a->{'up'} ? $text{'yes'} : $text{'no'}),"</td> </tr>\n";
	}
print "</table>\n";
print "<a href='edit_bifc.cgi?new=1'>$text{'ifcs_add'}</a>\n"
	if ($allow_add);
print "<a href='edit_range.cgi?new=1'>$text{'ifcs_radd'}</a>\n"
	if ($allow_add && defined(&supports_ranges) && &supports_ranges());
print "<p>\n";

&ui_print_footer("", $text{'index_return'});

sub iface_sort
{
return $a->{'name'} cmp $b->{'name'} if ($a->{'name'} cmp $b->{'name'});
return $a->{'virtual'} eq '' ? -1 :
       $b->{'virtual'} eq '' ? 1 : $a->{'virtual'} <=> $b->{'virtual'};
}

