# config-lib.pl
# Common functions for parsing config.info files
# Each module has a number of configurable parameters (stored in the config and
# config-* files in the module directory). Descriptions and possible values for
# each option are stored in the file config.info in the module directory.
# Each line of config.info looks like
# name=desc,type[,options]
#  desc - A description of the parameter
#  type - Possible types (and options) are
#	0 - Free text
#	1 - One of many (options are possibilities)
#	2 - Many of many (options are possibilities)
#	3 - Optional free text
#	4 - Like 1, but uses a pulldown menu
#	5 - User name
#	6 - Group name
#	7 - Directory
#	8 - File
#	9 - Multiline text
#	10 - Like 1, but with free text option
#	11 - Section header
#	12 - Password free text, with don't change option
#	13 - Like 2, but uses a list box
#	14 - Parameter is the name of a function in config_info.pl that
#	     returns an alternate set of config.info values.
#	15 - Parameter is the suffix for a pair of functions with show_
#	     and parse_ prepended.
#	16 - Password free text

# generate_config(&config, info-file, [module])
# Prints HTML for 
sub generate_config
{
local %config = %{$_[0]};
local $file = $_[1];

# Read the .info file in the right language
local (%info, @info_order, %einfo, $o);
&read_file($file, \%info, \@info_order);
%einfo = %info;
foreach $o (@lang_order_list) {
	&read_file("$file.$o", \%info, \@info_order);
	}
@info_order = &unique(@info_order);

# Show the parameter editors
local $c;
foreach $c (@info_order) {
	local @p = split(/,/, $info{$c});
	local @ep = split(/,/, $einfo{$c});
	if (scalar(@ep) > scalar(@p)) {
		push(@p, @ep[scalar(@p) .. @ep-1]);
		}
	if ($p[1] == 14) {
		$_[2] || &error($text{'config_ewebmin'});
		&foreign_require($_[2], "config_info.pl");
		local @newp = &foreign_call($_[2], $p[2], @p);
		$newp[0] ||= $p[0];
		@p = @newp;
		}
	if ($p[1] == 11) {
		print "<tr><td colspan=3 $tb>\n" ;
		print "\t<b>" . $p[0] . "</b>\n</td></tr>\n" ;
		next;
		}
	if ($p[1] == 16 && $config{'config_16_insecure'}) {
		# Don't allow mode 16
		$p[1] = 12;
		}
	print "<tr> <td valign=top><b>$p[0]</b></td>\n";
	print "<td nowrap>\n";
	if ($p[1] == 0) {
		$size = $p[2] ? "size=$p[2]" : "size=40";
		$max = $p[3] ? "maxlength=$p[3]" : "";
		print "<input name=\"$c\" $size $max value=\"",
			&html_escape($config{$c}),"\"> $p[4]\n";
		}
	elsif ($p[1] == 1) {
		local $len = 0;
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			$len += length($2);
			}
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			printf "<input type=radio name=\"$c\" value='$1' %s>\n",
				$config{$c} eq $1 ? "checked" : "";
			print $2;
			if ($len > 50) {
				print "<br>\n";
				}
			else {
				print " &nbsp;&nbsp;\n";
				}
			}
		}
	elsif ($p[1] == 2) {
		local %sel;
		map { $sel{$_}++ } split(/,/, $config{$c});
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			printf "<input type=checkbox name=\"$c\" value='$1' %s>\n", $sel{$1} ? "checked" : "";
			print "$2 &nbsp;&nbsp;\n";
			}
		}
	elsif ($p[1] == 3) {
		$none = $p[2] ? $p[2] : $text{'config_none'};
		$size = $p[3] ? "size=$p[3]" : "size=20";
		$max = $p[4] ? "maxlength=$p[4]" : "";
		printf "<input type=radio name=\"%s_none\" value=1 %s> $none\n",
			$c, $config{$c} eq "" ? "checked" : "";
		print "&nbsp;&nbsp;\n";
		printf "<input type=radio name=\"%s_none\" value=0 %s>\n",
			$c, $config{$c} eq "" ? "" : "checked";
		print "<input name=\"$c\" $size $max value=\"",
			&html_escape($config{$c}),"\"> $p[5]\n";
		}
	elsif ($p[1] == 4) {
		print "<select name=\"$c\">\n";
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			printf "<option value=\"$1\" %s>$2\n",
				$config{$c} eq $1 ? "selected" : "";
			}
		print "</select>\n";
		}
	elsif ($p[1] == 5) {
		if ($p[2]) {
			printf
			   "<input type=radio name=${c}_def value=1 %s>$p[2]\n",
			   $config{$c} eq "" ? "checked" : "";
			printf "<input type=radio name=${c}_def value=0 %s>\n",
			   $config{$c} eq "" ? "" : "checked";
			}
		print &unix_user_input($c, $config{$c});
		}
	elsif ($p[1] == 6) {
		if ($p[2]) {
			printf
			   "<input type=radio name=${c}_def value=1 %s>$p[2]\n",
			   $config{$c} eq "" ? "checked" : "";
			printf "<input type=radio name=${c}_def value=0 %s>\n",
			   $config{$c} eq "" ? "" : "checked";
			}
		print &unix_group_input($c, $config{$c});
		}
	elsif ($p[1] == 7) {
		print "<input name=\"$c\" size=40 value=\"",
			&html_escape($config{$c}),"\"> ",
			&file_chooser_button($c, 1);
		}
	elsif ($p[1] == 8) {
		print "<input name=\"$c\" size=40 value=\"",
			&html_escape($config{$c}),"\"> ",
			&file_chooser_button($c, 0);
		}
	elsif ($p[1] == 9) {
		local $cols = $p[2] ? $p[2] : 40;
		local $rows = $p[3] ? $p[3] : 5;
		local $sp = $p[4] ? eval "\"$p[4]\"" : " ";
		print "<textarea name=\"$c\" rows=$rows cols=$cols>",
			join("\n", split(/$sp/, $config{$c})),
			"</textarea>\n";
		}
	elsif ($p[1] == 10) {
		local $len = 20;
		for($i=2; $i<@p; $i++) {
			if ($p[$i] =~ /^(\S*)\-(.*)$/) {
				$len += length($2);
				}
			else {
				$len += length($p[$i]);
				}
			}
		local $fv = $config{$c};
		for($i=2; $i<@p; $i++) {
			($p[$i] =~ /^(\S*)\-(.*)$/) || next;
			printf "<input type=radio name=\"$c\" value=\"$1\" %s>\n",
				$config{$c} eq $1 ? "checked" : "";
			print $2;
			if ($len > 50) {
				print "<br>\n";
				}
			else {
				print " &nbsp;&nbsp;\n";
				}
			$fv = undef if ($config{$c} eq $1);
			}
		printf "<input type=radio name=\"$c\" value=free %s>\n",
			$fv ? "checked" : "";
		if ($p[$#p] !~ /^(\S*)\-(.*)$/) {
			print $p[$#p],"\n";
			}
		print "<input name=\"${c}_free\" value='$fv' size=20>\n";
		}
	elsif ($p[1] == 12) {
		print "<input type=radio name=\"${c}_nochange\" value=1 checked> $text{'config_nochange'}\n";
		print "<input type=radio name=\"${c}_nochange\" value=0> $text{'config_setto'}\n";
		$size = $p[2] ? "size=$p[2]" : "size=40";
		$max = $p[3] ? "maxlength=$p[3]" : "";
		print "<input name=\"$c\" type=password $size $max>\n";
		}
	elsif ($p[1] == 13) {
		local %sel;
		map { $sel{$_}++ } split(/,/, $config{$c});
		print "<select name=\"$c\" size=5 multiple>\n";
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			printf "<option value='$1' %s>$2\n",
					$sel{$1} ? "selected" : "";
			}
		print "</select>\n";
		}
	elsif ($p[1] == 15) {
		$_[2] || &error($text{'config_ewebmin'});
		&foreign_require($_[2], "config_info.pl");
		local $html = &foreign_call($_[2], "show_".$p[2],
					    $config{$c}, @p);
		print $html;
		}
	elsif ($p[1] == 16) {
		$size = $p[2] ? "size=$p[2]" : "size=40";
		$max = $p[3] ? "maxlength=$p[3]" : "";
		print "<input name=\"$c\" type=password $size $max>\n";
		}

	print "</td> </tr>\n";
	}
}

# parse_config(&config, info-file, [module])
# Updates the specified configuration with values from %in
sub parse_config
{
local ($config, $file) = @_;

# Read the .info file
local (%info, @info_order, $o);
&read_file($file, \%info, \@info_order);
foreach $o (@lang_order_list) {
	&read_file("$file.$o", \%info, \@info_order);
	}
@info_order = &unique(@info_order);

# Actually parse the inputs
local $c;
foreach $c (@info_order) {
	local @p = split(/,/, $info{$c});
	if ($p[1] == 14) {
		$_[2] || &error($text{'config_ewebmin'});
		&foreign_require($_[2], "config_info.pl");
		local @newp = &foreign_call($_[2], $p[2]);
		$newp[0] ||= $p[0];
		@p = @newp;
		}
	if ($p[1] == 16 && $config{'config_16_insecure'}) {
		# Don't allow mode 16
		$p[1] = 12;
		}
	if ($p[1] == 0 || $p[1] == 7 || $p[1] == 8 || $p[1] == 16) {
		# Free text input
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 1 || $p[1] == 4) {
		# One of many
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 5 || $p[1] == 6) {
		# User or group
		$config->{$c} = ($p[2] && $in{$c."_def"} ? "" : $in{$c});
		}
	elsif ($p[1] == 2 || $p[1] == 13) {
		# Many of many
		$in{$c} =~ s/\0/,/g;
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 3) {
		# Optional free text
		if ($in{$c."_none"}) { $config->{$c} = ""; }
		else { $config->{$c} = $in{$c}; }
		}
	elsif ($p[1] == 9) {
		# Multilines of free text
		local $sp = $p[4] ? eval "\"$p[4]\"" : " ";
		$in{$c} =~ s/\r//g;
		$in{$c} =~ s/\n/$sp/g;
		$in{$c} =~ s/\s+$//;
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 10) {
		# One of many or free text
		if ($in{$c} eq 'free') {
			$config->{$c} = $in{$c.'_free'};
			}
		else {
			$config->{$c} = $in{$c};
			}
		}
	elsif ($p[1] == 12) {
		# Optionally changed password
		if (!$in{"${c}_nochange"}) {
			$config->{$c} = $in{$c};
			}
		}
	elsif ($p[1] == 15) {
		# Parse custom HTML field
		$_[2] || &error($text{'config_ewebmin'});
		&foreign_require($_[2], "config_info.pl");
		local $pkg = $_[2];
		$pkg =~ s/[^A-Za-z0-9]/_/g;
		eval "\%${pkg}::in = \%in";
		$config{$c} = &foreign_call($_[2], "parse_".$p[2],
					    $config{$c}, @p);
		}
	}
}

1;

