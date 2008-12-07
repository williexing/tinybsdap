#!/usr/bin/perl
# edit_aifc.cgi
# Edit or create an active interface

require './net-lib.pl';

&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'aifc_create'}, "");
	&can_create_iface() || &error($text{'ifcs_ecannot'});
	}
else {
	@act = &active_interfaces();
	$a = $act[$in{'idx'}];
	&can_iface($a) || &error($text{'ifcs_ecannot_this'});
	&ui_print_header(undef, $text{'aifc_edit'}, "");
	}

print "<form action=save_aifc.cgi>\n";
print "<input type=hidden name=new value=\"$in{'new'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",
      $in{'virtual'} || $a && $a->{'virtual'} ne "" ? $text{'aifc_desc2'}
						    : $text{'aifc_desc1'},
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'ifcs_name'}</b></td> <td>\n";
if ($in{'new'} && $in{'virtual'}) {
	print "<input type=hidden name=name value=$in{'virtual'}>\n";
	print "$in{'virtual'}:<input name=virtual size=3>\n";
	}
elsif ($in{'new'}) {
	print "<input name=name size=6>\n";
	}
else {
	print "<font size=+1><tt>$a->{'fullname'}</tt></font>\n";
	}
print "</td>\n";

print "<td><b>$text{'ifcs_ip'}</b></td>\n";
printf "<td><input name=address size=15 value=\"%s\"></td> </tr>\n",
	$a ? $a->{'address'} : "";

print "<tr> <td><b>$text{'ifcs_mask'}</b></td> <td>\n";
printf "<input type=radio name=netmask_def value=1 %s> $text{'ifcs_auto'}\n",
	$a && $a->{'netmask'} ? "" : "checked";
printf "<input type=radio name=netmask_def value=0 %s>\n",
	$a && $a->{'netmask'} ? "checked" : "";
printf "<input name=netmask size=15 value=\"%s\"></td>\n",
	$a ? $a->{'netmask'} : "";

print "<td><b>$text{'ifcs_broad'}</b></td> <td>\n";
printf "<input type=radio name=broadcast_def value=1 %s> $text{'ifcs_auto'}\n",
	$a && $a->{'broadcast'} ? "" : "checked";
printf "<input type=radio name=broadcast_def value=0 %s>\n",
	$a && $a->{'broadcast'} ? "checked" : "";
printf "<input name=broadcast size=15 value=\"%s\"></td> </tr>\n",
	$a ? $a->{'broadcast'} : "";

print "<tr> <td><b>$text{'ifcs_mtu'}</b></td> <td>\n";
printf "<input type=radio name=mtu_def value=1 %s> $text{'aifc_default'}\n",
	$a && $a->{'mtu'} ? "" : "checked";
printf "<input type=radio name=mtu_def value=0 %s>\n",
	$a && $a->{'mtu'} ? "checked" : "";
printf "<input name=mtu size=15 value=\"%s\"></td>\n",
	$a ? $a->{'mtu'} : "";

print "<td><b>$text{'ifcs_status'}</b></td> <td>\n";
printf "<input type=radio name=up value=1 %s> $text{'ifcs_up'}\n",
	$a && !$a->{'up'} ? "" : "checked";
printf "<input type=radio name=up value=0 %s> $text{'ifcs_down'}</td> </tr>\n",
	$a && !$a->{'up'} ? "checked" : "";

if ((!$a && $in{'virtual'} eq "") ||
    ($a && $a->{'virtual'} eq "" && &iface_hardware($a->{'name'}))) {
	print "<tr> <td><b>$text{'aifc_hard'}</b></td> <td>\n";
	if ($in{'new'}) {
		printf "<input type=radio name=ether_def value=1 %s> %s\n",
			$a ? "" : "checked", $text{'aifc_default'};
		printf "<input type=radio name=ether_def value=0 %s>\n",
			$a ? "checked" : "";
		}
	printf "<input name=ether size=18 value=\"%s\"></td>\n",
		$a ? $a->{'ether'} : "";
	}
else {
	print "<tr> <td colspan=2></td>\n";
	}
if ($a && $a->{'virtual'} eq "") {
	print "<td><b>$text{'ifcs_virts'}</b></td>\n";
	$vcount = 0;
	foreach $va (@act) {
		if ($va->{'virtual'} ne "" && $va->{'name'} eq $a->{'name'}) {
			$vcount++;
			}
		}
	print "<td>$vcount\n";
	print "(<a href='edit_aifc.cgi?new=1&virtual=$a->{'name'}'>",
	      "$text{'ifcs_addvirt'}</a>)</td>\n";
	}
print "</tr>\n";
     

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value=\"$text{'create'}\"></td>\n";
	}
else {
	print "<td><input type=submit value=\"$text{'save'}\"></td> ",
	      "<td align=right>\n";
	print "<input type=submit name=delete value=\"$text{'delete'}\"></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("list_ifcs.cgi", $text{'ifcs_return'});

