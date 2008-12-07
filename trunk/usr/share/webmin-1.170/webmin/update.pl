#!/usr/local/bin/perl
# update.pl
# Find and install updated modules, and email out the result

$no_acl_check++;
require './webmin-lib.pl';

# Get the update source
if ($config{'upsource'}) {
	($host, $port, $page, $ssl) = &parse_http_url($config{'upsource'});
	$host || die "Invalid update source URL!";
	}
else {
	$host = $update_host;
	$port = $update_port;
	$page = $update_page;
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

# Go through the results
foreach $u (@updates) {
	# Skip modules that are not for this version of Webmin, IF the module
	# is a core module or is not installed
	local %minfo = &get_module_info($u->[0]);
	local %tinfo = &get_theme_info($u->[0]);
	local %info = %minfo ? %minfo : %tinfo;
	next if (($u->[1] >= &get_webmin_base_version() + .01 ||
		  $u->[1] < &get_webmin_base_version()) &&
		 (!%info || $info{'longdesc'} || !$config{'upthird'}));

	if (!%info && !$config{'upmissing'}) {
		$rv .= &text('update_mmissing', $u->[0])."\n"
			if (!$config{'upquiet'});
		next;
		}
	if (%info && $info{'version'} >= $u->[1]) {
		$rv .= &text('update_malready', $u->[0])."\n"
			if (!$config{'upquiet'});
		next;
		}
	local $osinfo = { 'os_support' => $u->[3] };
	if (!&check_os_support($osinfo)) {
		$rv .= &text('update_mos', $u->[0])."\n"
			if (!$config{'upquiet'});
		next;
		}
	if ($config{'upshow'}) {
		# Just tell the user what would be done
		$rv .= &text('update_mshow', $u->[0], $u->[1])."\n".
		       ($info{'longdesc'} ? "$text{'update_fixes'} : " : "").
		       $u->[4]."\n\n";
		}
	else {
		# Actually do the update .. XXX remove html from comments
		local (@mdescs, @mdirs, @msizes);
		$rv .= &text('update_mok', $u->[0], $u->[1])."\n".
		       ($info{'longdesc'} ? "$text{'update_fixes'} : " : "").
		       $u->[4]."\n\n";
		($mhost, $mport, $mpage, $mssl) =
			&parse_http_url($u->[2], $host, $port, $page, $ssl);
		$mtemp = &tempname();
		&http_download($mhost, $mport, $mpage, $mtemp, \$error,
			       undef, $mssl);
		if ($error) {
			$rv .= "$error\n\n";
			last;
			}
		else {
			$irv = &install_webmin_module($mtemp, 1, 0,
						      [ "admin", "root" ]);
			if (!ref($irv)) {
				$rv .= &text('update_failed', $irv)."\n\n";
				}
			else {
				$rv .= &text('update_mdesc', $irv->[0]->[0],
					      $irv->[2]->[0])."\n\n";
				}
			}
		}
	}

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
	$rv .= &text('update_version', $version)."\n";
	}

# Send off a results email
if ($config{'upemail'} && $rv && &foreign_check("mailboxes")) {
	# Construct and send the email
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	local $data;
	local $type = $gconfig{'real_os_type'} || $gconfig{'os_type'};
	local $version = $gconfig{'real_os_version'} || $gconfig{'os_version'};
	local $myhost = &get_system_hostname();
	$data .= "$myhost ($type $version)\n\n";
	$data .= &entities_to_ascii(
			&text('update_rv', "http://$host:$port$page"))."\n\n";
	$data .= &entities_to_ascii($rv);
	local $mail = { 'headers' => [ [ 'From',&mailboxes::get_from_address()],
				       [ 'To', $config{'upemail'} ],
				       [ 'Subject', $text{'update_subject'} ] ],
			'attach' =>
			[ { 'headers' => [ [ 'Content-type', 'text/plain' ] ],
			    'data' => $data } ] };
	&mailboxes::send_mail($mail);
	}

