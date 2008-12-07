#!/usr/bin/perl
# mass_start_stop.cgi
# Start or stop multiple actions at once

require './init-lib.pl';
%access = &get_module_acl();
&ReadParse();
@sel = split(/\0/, $in{'idx'});
@sel || &error($text{'mass_enone2'});

if ($in{'start'} || $in{'stop'}) {
	# Starting or stopping a bunch of actions
	&foreign_require("proc", "proc-lib.pl");
	$access{'bootup'} || &error($text{'ss_ecannot'});

	# build list of normal and broken actions
	($initrl) = &get_inittab_runlevel();
	@iacts = &list_actions();
	foreach $a (@iacts) {
		@ac = split(/\s+/, $a);
		push(@acts, $ac[0]);
		local $order = "9" x $config{'order_digits'};
		if ($ac[0] =~ /^\//) {
			push(@actsf, $ac[0]);
			}
		else {
			push(@actsf, "$config{'init_dir'}/$ac[0]");
			local @lvls = &action_levels($in{'start'} ? 'S' : 'K', $ac[0]);
			foreach $lon (@lvls) {
				local ($l, $o, $n) = split(/\s+/, $lon);
				if ($l eq $initrl) {
					$order = $o;
					last;
					}
				}
			}
		push(@orders, $order);
		}

	&ui_print_unbuffered_header(undef, $in{'start'} ? $text{'mass_start'} : $text{'mass_stop'}, "");
	if ($in{'start'}) {
		@sel = sort { $orders[$a] <=> $orders[$b] } @sel;
		}
	else {
		@sel = sort { $orders[$b] <=> $orders[$a] } @sel;
		}
	foreach $idx (@sel) {
		local $cmd = "$actsf[$idx] ".($in{'start'} ? "start" : "stop");
		print &text('ss_exec', "<tt>$cmd</tt>"),"<p>\n";
		print "<pre>";
		&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
		print "</pre>\n";
		push(@selacts, $acts[$idx]);
		}
	&webmin_log($in{'start'} ? 'massstart' : 'massstop', 'action',
		    join(" ", @selacts));
	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Enabling or disabling a bunch of actions
	$access{'bootup'} == 1 || &error($text{'edit_ecannot'});
	@iacts = &list_actions();
	foreach $a (@iacts) {
		@ac = split(/\s+/, $a);
		push(@acts, $ac[0]);
		}
	@toboot = map { $acts[$_] } @sel;
	foreach $b (@toboot) {
		if ($b =~ /^\//) {
			&error(&text('mass_ebroken', $ac[0]));
			}
		}
	if ($in{'addboot'}) {
		# Enable them all
		foreach $b (@toboot) {
			&enable_at_boot($b);
			}
		}
	else {
		# Disable them all
		foreach $b (@toboot) {
			&disable_at_boot($b);
			}
		}
	&redirect("");
	}

