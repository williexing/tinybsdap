#!/usr/bin/perl
# save_bifc.cgi
# Create, save or delete a boot-time interface

require './net-lib.pl';
&ReadParse();
@boot = &boot_interfaces();

if ($in{'delete'} || $in{'unapply'}) {
	# Delete interface
	&error_setup($text{'bifc_err1'});
	$b = $boot[$in{'idx'}];
	&can_iface($b) || &error($text{'ifcs_ecannot_this'});

	if ($in{'unapply'}) {
		# Shut down this interface active (if active)
		&error_setup($text{'bifc_err4'});
		@active = &active_interfaces();
		($act) = grep { $_->{'fullname'} eq $b->{'fullname'} } @active;
		if ($act) {
			if (defined(&unapply_interface)) {
				$err = &unapply_interface($act);
				$err && &error("<pre>$err</pre>");
				}
			else {
				&deactivate_interface($act);
				}
			}

		}
	&delete_interface($b);
	&webmin_log("delete", "bifc", $b->{'fullname'}, $b);
	}
else {
	# Save or create interface
	&error_setup($text{'bifc_err2'});
	if (!$in{'new'}) {
		$oldb = $boot[$in{'idx'}];
		&can_iface($oldb) || &error($text{'ifcs_ecannot_this'});
		$b->{'name'} = $oldb->{'name'};
		$b->{'file'} = $oldb->{'file'};
		$b->{'gateway'} = $oldb->{'gateway'};
		$b->{'virtual'} = $oldb->{'virtual'}
			if (defined($oldb->{'virtual'}));
		}
	elsif (defined($in{'virtual'})) {
		# creating a virtual interface
		$in{'virtual'} =~ /^\d+$/ ||
			&error($text{'bifc_evirt'});
		$in{'virtual'} >= $min_virtual_number ||
			&error(&text('aifc_evirtmin', $min_virtual_number));
		foreach $eb (@boot) {
			if ($eb->{'name'} eq $in{'name'} &&
			    $eb->{'virtual'} eq $in{'virtual'}) {
				&error(&text('bifc_evirtdup',
				       "$in{'name'}:$in{'virtual'}"));
				}
			}
		$b->{'name'} = $in{'name'};
		$b->{'virtual'} = $in{'virtual'};
		&can_create_iface() || &error($text{'ifcs_ecannot'});
		&can_iface($b) || &error($text{'ifcs_ecannot'});
		}
	elsif ($in{'name'} =~ /^([a-z]+\d*(\.\d+)?):(\d+)$/) {
		# also creating a virtual interface
		foreach $eb (@boot) {
			if ($eb->{'name'} eq $1 &&
			    $eb->{'virtual'} eq $3) {
				&error(&text('bifc_evirtdup', $in{'name'}));
				}
			}
		$3 >= $min_virtual_number ||
			&error(&text('aifc_evirtmin', $min_virtual_number));
		$b->{'name'} = $1;
		$b->{'virtual'} = $3;
		&can_create_iface() || &error($text{'ifcs_ecannot'});
		&can_iface($b) || &error($text{'ifcs_ecannot'});
		}
	elsif ($in{'name'} =~/^[a-z]+\d*(\.\d+)?$/) {
		# creating a real interface
		foreach $eb (@boot) {
			if ($eb->{'fullname'} eq $in{'name'}) {
				&error(&text('bifc_edup', $in{'name'}));
				}
			}
		$b->{'name'} = $in{'name'};
		&can_create_iface() || &error($text{'ifcs_ecannot'});
		&can_iface($b) || &error($text{'ifcs_ecannot'});
		}
	else {
		&error($text{'bifc_ename'});
		}

	# Check for address clash
	$allow_clash = defined(&allow_interface_clash) ?
			&allow_interface_clash($b, 1) : 1;
	if (!$allow_clash && $in{'mode'} eq 'address' &&
	    ($in{'new'} || $oldb->{'address'} ne $in{'address'})) {
		($clash) = grep { $_->{'address'} eq $in{'address'} &&
				  $_->{'up'} } @boot;
		$clash && &error(&text('aifc_eclash', $clash->{'fullname'}));
		}

	# Validate and store inputs
	if ($in{'mode'} eq 'dhcp' || $in{'mode'} eq 'bootp') {
		$in{'activate'} && !defined(&apply_interface) &&
			&error($text{'bifc_eapply'});
		$b->{$in{'mode'}}++;
		$auto++;
		}
	else {
		&valid_boot_address($in{'address'}) ||
			&error(&text('bifc_eip', $in{'address'}));
		$b->{'address'} = $in{'address'};
		}
	if (&can_edit("netmask", $b)) {
		$auto && !$in{'netmask'} || &check_ipaddress($in{'netmask'}) ||
			&error(&text('bifc_emask', $in{'netmask'}));
		$b->{'netmask'} = $in{'netmask'};
		}
	if (&can_edit("broadcast", $b)) {
		$auto && !$in{'broadcast'} ||
			&check_ipaddress($in{'broadcast'}) ||
			&error(&text('bifc_ebroad', $in{'broadcast'}));
		$b->{'broadcast'} = $in{'broadcast'};
		}
	if (&can_edit("mtu", $b)) {
		$auto && !$in{'mtu'} ||
			$in{'mtu'} =~ /^\d*$/ ||
			&error(&text('bifc_emtu', $in{'mtu'}));
		$b->{'mtu'} = $in{'mtu'};
		}
	if ($in{'up'} && &can_edit("up", $b)) { $b->{'up'}++; }
	$b->{'fullname'} = $b->{'name'}.
			   ($b->{'virtual'} eq '' ? '' : ':'.$b->{'virtual'});
	&save_interface($b);

	if ($in{'activate'}) {
		# Make this interface active (if possible)
		&error_setup($text{'bifc_err3'});
		$b->{'up'}++;
		$b->{'address'} = &to_ipaddress($b->{'address'});
		if (defined(&apply_interface)) {
			$err = &apply_interface($b);
			$err && &error("<pre>$err</pre>");
			}
		else {
			&activate_interface($b);
			}
		}
	&webmin_log($in{'new'} ? 'create' : 'modify',
		    "bifc", $b->{'fullname'}, $b);
	}
&redirect("list_ifcs.cgi");

