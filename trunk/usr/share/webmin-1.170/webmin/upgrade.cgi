#!/usr/local/bin/perl
# upgrade.cgi
# Upgrade webmin if possible

require './webmin-lib.pl';
require './gnupg-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&ReadParseMime();

$| = 1;
$theme_no_table = 1;
&ui_print_header(undef, $text{'upgrade_title'}, "");

# Save this CGI from being killed by the upgrade
$SIG{'TERM'} = 'IGNORE';

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&text('upgrade_err1', $in{'file'}));
	$file = $in{'file'};
	if (!(-r $file)) { &inst_error($text{'upgrade_efile'}); }
	if ($file =~ /webmin-(\d+\.\d+)/) {
		$version = $1;
		}
	}
elsif ($in{'source'} == 1) {
	# from uploaded file
	&error_setup($text{'upgrade_err2'});
	$file = &tempname();
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($text{'upgrade_ebrowser'});
                }
	open(MOD, ">$file");
	print MOD $in{'upload'};
	close(MOD);
	if ($in{'upload_filename'} =~ /webmin-(\d+\.\d+)/) {
		$version = $1;
		}
	}
elsif ($in{'source'} == 2) {
	# find latest version at www.webmin.com by looking at index page
	&error_setup($text{'upgrade_err3'});
	$file = &tempname();
	&http_download($update_host, $update_port, '/', $file, \$error);
	$error && &inst_error($error);
	open(FILE, $file);
	while(<FILE>) {
		if (/webmin-([0-9\.]+)\.tar\.gz/) {
			$version = $1;
			last;
			}
		}
	close(FILE);
	unlink($file);
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}
	if ($in{'mode'} eq 'rpm') {
		$progress_callback_url = "http://$update_host/download/rpm/webmin-$version-1.noarch.rpm";
		&http_download($update_host, $update_port,
		  "/download/rpm/webmin-$version-1.noarch.rpm", $file,
		  \$error, \&progress_callback);
		}
	elsif ($in{'mode'} eq 'solaris-pkg') {
		$progress_callback_url = "http://$update_host/download/rpm/webmin-$version.pkg.gz";
		&http_download($update_host, $update_port,
		  "/download/solaris-pkg/webmin-$version.pkg.gz", $file,
		  \$error, \&progress_callback);
		}
	else {
		$progress_callback_url = "http://$update_host/download/webmin-$version.tar.gz";
		&http_download($update_host, $update_port,
		  "/download/webmin-$version.tar.gz", $file,
		  \$error, \&progress_callback);
		}
	$error && &inst_error($error);
	$need_unlink = 1;
	}
elsif ($in{'source'} == 5) {
	# Download from some URL
	&error_setup(&text('upgrade_err5', $in{'url'}));
	$file = &tempname();
	$progress_callback_url = $in{'url'};
	if ($in{'url'} =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
		$ssl = $1 eq 'https';
		$host = $2; $page = $3; $port = $ssl ? 443 : 80;
		if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
		&http_download($host, $port, $page, $file, \$error,
			       \&progress_callback, $ssl);
		}
	elsif ($in{'url'} =~ /^ftp:\/\/([^\/]+)(:21)?\/(.*)$/) {
		$host = $1; $ffile = $3;
		&ftp_download($host, $ffile, $file,
			      \$error, \&progress_callback);
		}
	else { &inst_error($text{'upgrade_eurl'}); }
	$need_unlink = 1;
	$error && &inst_error($error);
	if ($in{'url'} =~ /webmin-(\d+\.\d+)/) {
		$version = $1;
		}
	}
elsif ($in{'source'} == 3) {
	# Get the latest version from Caldera with cupdate
	&redirect("/cupdate/");
	}
elsif ($in{'source'} == 4) {
	# Just run the command  emerge webmin
	&error_setup(&text('upgrade_err4'));
	$file = "webmin";
	$need_unlink = 0;
	}

# Import the signature for RPM
if ($in{'mode'} eq 'rpm') {
	system("rpm --import $module_root_directory/jcameron-key.asc >/dev/null 2>&1");
	}

# Check the signature if possible
if ($in{'sig'}) {
	# Check the package signature
	($ec, $emsg) = &gnupg_setup();
	if (!$ec) {
		if ($in{'mode'} eq 'rpm') {
			# Use rpm's gpg signature verification
			local $out = `rpm --checksig $file 2>&1`;
			if ($?) {
				$ec = 3;
				$emsg = &text('upgrade_echecksig',
					      "<pre>$out</pre>");
				}
			}
		else {
			# Do a manual signature check
			if ($in{'source'} == 2) {
				# Download the key for this tar.gz
				local ($sigtemp, $sigerror);
				&http_download($update_host, $update_port, "/download/sigs/webmin-$version.tar.gz-sig.asc", \$sigtemp, \$sigerror);
				if ($sigerror) {
					$ec = 4;
					$emsg = &text('upgrade_edownsig',
						      $sigerror);
					}
				else {
					local $data = `cat $file`;
					local ($vc, $vmsg) =
					    &verify_data($data, $sigtemp);
					if ($vc > 1) {
						$ec = 3;
						$emsg = &text(
						    "upgrade_everify$vc",
						    &html_escape($vmsg));
						}
					}
				}
			else {
				$emsg = $text{'upgrade_nosig'};
				}
			}
		}

	# Tell the user about any GnuPG error
	if ($ec) {
		&inst_error($emsg);
		}
	elsif ($emsg) {
		print "$emsg<p>\n";
		}
	else {
		print "$text{'upgrade_sigok'}<p>\n";
		}
	}
else {
	print "$text{'upgrade_nocheck'}<p>\n";
	}

if ($in{'mode'} ne 'gentoo') {
	# gunzip the file if needed
	open(FILE, $file);
	read(FILE, $two, 2);
	close(FILE);
	if ($two eq "\037\213") {
		if (!&has_command("gunzip")) {
			&inst_error($text{'upgrade_egunzip'});
			}
		$newfile = &tempname();
		$out = `gunzip -c $file 2>&1 >$newfile`;
		if ($?) {
			unlink($newfile);
			&inst_error(&text('upgrade_egzip', "<tt>$out</tt>"));
			}
		unlink($file) if ($need_unlink);
		$need_unlink = 1;
		$file = $newfile;
		}
	}

# Get list of updates
$updatestemp = &tempname();
&http_download($update_host, $update_port, "/updates/updates.txt", $updatestemp,
	       \$updates_error);

if ($in{'mode'} eq 'rpm') {
	# Check if it is an RPM package
	$out = `rpm -qp $file`;
	$out =~ /(^|\n)webmin-(\d+\.\d+)/ ||
		&inst_error($text{'upgrade_erpm'});
	$version = $2;
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	# Install the RPM
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	print "<p>",$text{'upgrade_setuprpm'},"<p>\n";
	print "<pre>";
	&proc::safe_process_exec("rpm -U --ignoreos --ignorearch '$file'", 0, 0,
			   	 STDOUT, undef, 1, 1);
	unlink($file) if ($need_unlink);
	print "</pre>\n";
	}
elsif ($in{'mode'} eq 'solaris-pkg') {
	# Check if it is a solaris package
	# XXX not actually used
	&foreign_require("software", "software-lib.pl");
	&foreign_call("software", "is_package", $file) ||
		&inst_error($text{'upgrade_epackage'});
	local @p = &foreign_call("software", "file_packages", $file);
	$p[0] =~ /^WSwebmin/ || &inst_error($text{'upgrade_epackage'});

	# Install the package
	print "<p>",$text{'upgrade_setuppackage'},"<p>\n";
	$ENV{'KEEP_ETC_WEBMIN'} = 1;
	if (!fork()) {
		chdir("/");
		close(STDIN); close(STDOUT); close(STDERR);
		$rv = &foreign_call("software", "delete_package", "WSwebmin");
		$software::in{'root'} = '/';
		$rv = &foreign_call("software", "install_package", $file, "WSwebmin");
		unlink($file) if ($need_unlink);
		exit;
		}
	}
elsif ($in{'mode'} eq 'caldera') {
	# Check if it is a Caldera RPM of Webmin
	$out = `rpm -qp $file`;
	$out =~ /^webmin-(\d+\.\d+)/ ||
		&inst_error($text{'upgrade_erpm'});
	if ($1 <= &get_webmin_version() && !$in{'force'}) {
		&inst_error(&text('upgrade_eversion', "$1"));
		}
	local $wfound = 0;
	open(OUT, "rpm -qpl $file |");
	while(<OUT>) {
		$wfound++ if (/^\/etc\/webmin/);
		}
	close(OUT);
	$wfound || &inst_error($text{'upgrade_ecaldera'});

	# Install the RPM
	print "<p>",$text{'upgrade_setuprpm'},"<p>\n";
	print "<pre>";
	&proc::safe_process_exec("rpm -U --ignoreos --ignorearch '$file'", 0, 0,
			   STDOUT, undef, 1, 1);
	unlink($file) if ($need_unlink);
	print "</pre>\n";
	}
elsif ($in{'mode'} eq 'gentoo') {
	# Check if it is a gentoo .tar.gz or .ebuild file of webmin
	open(EMERGE, "emerge --pretend '$file' 2>/dev/null |");
	while(<EMERGE>) {
		s/\r|\n//g;
		s/\033[^m]+m//g;
		if (/\s+[NRU]\s+\]\s+([^\/]+)\/webmin\-(\d\S+)/) {
			$version = $2;
			}
		}
	close(EMERGE);
	$version || &inst_error($text{'upgrade_egentoo'});
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	# Install the Gentoo package
	print "<p>",$text{'upgrade_setupgentoo'},"<p>\n";
	print "<pre>";
	&proc::safe_process_exec("emerge '$file'", 0, 0, STDOUT, undef, 1, 1);
	unlink($file) if ($need_unlink);
	print "</pre>\n";
	}
else {
	# Check if it is a webmin tarfile
	open(TAR, "tar tf $file 2>&1 |");
	while(<TAR>) {
		s/\r|\n//g;
		if (/^webmin-([0-9\.]+)\//) {
			$version = $1;
			}
		if (/^usermin-([0-9\.]+)\//) {
			$usermin_version = $1;
			}
		if (/^[^\/]+\/(\S+)$/) {
			$hasfile{$1}++;
			}
		if (/^(webmin-([0-9\.]+)\/[^\/]+)$/) {
			push(@topfiles, $1);
			}
		elsif (/^webmin-[0-9\.]+\/([^\/]+)\//) {
			$intar{$1}++;
			}
		}
	close(TAR);
	if ($usermin_version) {
		&inst_error(&text('upgrade_eusermin', $usermin_version));
		}
	if (!$version) {
		if ($hasfile{'module.info'}) {
			&inst_error(&text('upgrade_emod', 'edit_mods.cgi'));
			}
		else {
			&inst_error($text{'upgrade_etar'});
			}
		}
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	# Work out where to extract
	if ($in{'dir'}) {
		# Since we are currently installed in a fixed directory,
		# just extract to a temporary location
		$extract = &tempname();
		mkdir($extract, 0755);
		}
	else {
		# Next to the current directory
		$extract = "../..";
		}

	# Do the extraction of the tar file, and run setup.sh
	$| = 1;
	if ($in{'only'}) {
		# Extract only root files and modules that we already have
		# Make sure that themes and other directories are included
		$topfiles = join(" ", map { quotemeta($_) } @topfiles);
		$out = `cd $extract ; tar xf $file $topfiles 2>&1 >/dev/null`;
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		@mods = grep { $intar{$_} } map { $_->{'dir'} }
			     &get_all_module_infos(1);
		opendir(DIR, $root_directory);
		foreach $d (readdir(DIR)) {
			next if ($d =~ /^\./);
			local $p = "$root_directory/$d";
			if (-d $p && !-r "$p/module.info" && $intar{$d}) {
				push(@mods, $d);
				}
			}
		closedir(DIR);
		$mods = join(" ", map { quotemeta("webmin-$version/$_") }
				      @mods);
		$out = `cd $extract ; tar xf $file $mods 2>&1 >/dev/null`;
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		}
	else {
		# Extract the whole file
		$out = `cd $extract ; tar xf $file 2>&1 >/dev/null`;
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		}
	unlink($file) if ($need_unlink);
	$ENV{'config_dir'} = $config_directory;
	$ENV{'webmin_upgrade'} = 1;
	$ENV{'autothird'} = 1;
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	$ENV{'deletedold'} = 1 if ($in{'delete'});
	print "<p>",$text{'upgrade_setup'},"<p>\n";
	print "<pre>";
	$setup = $in{'dir'} ? "./setup.sh '$in{'dir'}'" : "./setup.sh";
	&proc::safe_process_exec(
		"cd $extract/webmin-$version && $setup", 0, 0,
		STDOUT, undef, 1, 1);
	print "</pre>\n";
	if (!$?) {
		if ($in{'delete'}) {
			# Can delete the old root directory
			system("rm -rf \"$root_directory\"");
			}
		elsif ($in{'dir'}) {
			# Can delete the temporary source directory
			system("rm -rf \"$extract\"");
			}
		}
	}
&webmin_log("upgrade", undef, undef, { 'version' => $version,
				       'mode' => $in{'mode'} });

# Find out about any updates for this new version.
if ($updates_error) {
	print "<br>",&text('upgrade_eupdates', $updates_error),"<p>\n";
	}
else {
	open(UPDATES, $updatestemp);
	while(<UPDATES>) {
		if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+(.*)/) {
			push(@updates, [ $1, $2, $3, $4, $5 ]);
			}
		}
	close(UPDATES);
	unlink($updatestemp);
	$bversion = &base_version($version);
	foreach $u (@updates) {
		next if ($u->[1] >= $bversion + .01 || $u->[1] <= $bversion ||
			 $u->[1] <= $version);
		local $osinfo = { 'os_support' => $u->[3] };
		next if (!&check_os_support($osinfo));
		$ucount++;
		}
	if ($ucount) {
		print "<br>",&text('upgrade_updates', $ucount,
			"update.cgi?source=0&show=0&missing=0"),"<p>\n";
		}
	}

&ui_print_footer("", $text{'index_return'});

sub inst_error
{
unlink($file) if ($need_unlink);
unlink($updatestemp);
print "<br><b>$whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

