#!/usr/local/bin/perl
# update.cgi
# Find and install modules that need updating

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'update_err'});

# Validate inputs
if ($in{'source'} == 0) {
	$host = $update_host;
	$port = $update_port;
	$page = $update_page;
	}
else {
	($host, $port, $page, $ssl) = &parse_http_url($in{'other'});
	$host || &error($text{'update_eurl'});
	}

# Retrieve the updates list (format is  module version url support description )
$temp = &tempname();
&http_download($host, $port, $page, $temp, undef, undef, $ssl);
open(UPDATES, $temp);
while(<UPDATES>) {
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+(.*)/) {
		push(@updates, [ $1, $2, $3, $4, $5 ]);
		}
	}
close(UPDATES);
unlink($temp);
@updates || &error($text{'update_efile'});

# Display the results and maybe take action
$| = 1;
$theme_no_table = 1;
&ui_print_header(undef, $text{'update_title'}, "");

print "<b>",&text('update_info'),"</b><p>\n";
foreach $u (@updates) {
	# Skip modules that are not for this version of Webmin, IF the module
	# is a core module or is not installed
	local %minfo = &get_module_info($u->[0]);
	local %tinfo = &get_theme_info($u->[0]);
	local %info = %minfo ? %minfo : %tinfo;
	next if (($u->[1] >= &get_webmin_base_version() + .01 ||
		  $u->[1] < &get_webmin_base_version()) &&
		 (!%info || $info{'longdesc'} || !$in{'third'}));

	$count++;
	if (!%info && !$in{'missing'}) {
		print &text('update_mmissing', "<b>$u->[0]</b>"),"<p>\n";
		next;
		}
	if (%info && $info{'version'} >= $u->[1]) {
		print &text('update_malready', "<b>$u->[0]</b>"),"<p>\n";
		next;
		}
	local $osinfo = { 'os_support' => $u->[3] };
	if (!&check_os_support($osinfo)) {
		print &text('update_mos', "<b>$u->[0]</b>"),"<p>\n";
		next;
		}
	if ($in{'show'}) {
		# Just tell the user what would be done
		print &text('update_mshow', "<b>$u->[0]</b>", "<b>$u->[1]</b>"),
		      "<br>\n";
		print "&nbsp;" x 10;
		print "$text{'update_fixes'} : " if ($info{'longdesc'});
		print $u->[4],"<p>\n";
		}
	else {
		# Actually do the update ..
		local (@mdescs, @mdirs, @msizes);
		print &text('update_mok', "<b>$u->[0]</b>", "<b>$u->[1]</b>"),
		      "<br>\n";
		print "&nbsp;" x 10;
		print "$text{'update_fixes'} : " if ($info{'longdesc'});
		print $u->[4],"<br>\n";
		($mhost, $mport, $mpage, $mssl) =
			&parse_http_url($u->[2], $host, $port, $page, $ssl);
		$mtemp = &tempname();
		$progress_callback_url = $u->[2];
		$progress_callback_prefix = "&nbsp;" x 10;
		&http_download($mhost, $mport, $mpage, $mtemp, undef,
			       \&progress_callback, $mssl);
		$irv = &install_webmin_module($mtemp, 1, 0,
					      [ $base_remote_user ]);
		print "&nbsp;" x 10;
		if (!ref($irv)) {
			print &text('update_failed', $irv),"<p>\n";
			}
		else {
			print &text('update_mdesc', "<b>$irv->[0]->[0]</b>",
				    "<b>$irv->[2]->[0]</b>"),"<p>\n";
			}
		}
	}
print &text('update_none'),"<br>\n" if (!$count);

# Check if a new version of webmin itself is available
$file = &tempname();
&http_download('www.webmin.com', 80, '/', $file);
open(FILE, $file);
while(<FILE>) {
	if (/webmin-([0-9\.]+)\.tar\.gz/) {
		$version = $1;
		last;
		}
	}
close(FILE);
unlink($file);
if ($version > &get_webmin_version()) {
	print "<b>",&text('update_version', $version),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

