# webmin-lib.pl
# Common functions for configuring miniserv

do '../web-lib.pl';
&init_config();
require '../ui-lib.pl';

@cs_codes = ( 'cs_page', 'cs_text', 'cs_table', 'cs_header', 'cs_link' );
@cs_names = map { $text{$_} } @cs_codes;

$update_host = "www.webmin.com";
$update_port = 80;
$update_page = "/updates/updates.txt";

$webmin_key_email = "jcameron\@webmin.com";
$webmin_key_fingerprint = "1719 003A CE3E 5A41 E2DE  70DF D97A 3AE9 11F6 3C51";

$standard_host = $update_host;
$standard_port = $update_port;
$standard_page = "/download/modules/standard.txt";
$standard_ssl = 0;

$third_host = $update_host;
$third_port = $update_port;
$third_page = "/cgi-bin/third.cgi";
$third_ssl = 0;

$default_key_size = "512";

sub setup_ca
{
local $conf = `cat $root_directory/acl/openssl.cnf`;
local $acl = "$config_directory/acl";
$conf =~ s/DIRECTORY/$acl/g;
&lock_file("$acl/openssl.cnf");
open(CONF, ">$acl/openssl.cnf");
print CONF $conf;
close(CONF);
chmod(0600, "$acl/openssl.cnf");
&unlock_file("$acl/openssl.cnf");
&lock_file("$acl/index.txt");
open(INDEX, ">$acl/index.txt");
close(INDEX);
chmod(0600, "$acl/index.txt");
&unlock_file("$acl/index.txt");
&lock_file("$acl/serial");
open(SERIAL, ">$acl/serial");
print SERIAL "011E\n";
close(SERIAL);
chmod(0600, "$acl/serial");
&unlock_file("$acl/serial");
&lock_file("$acl/newcerts");
mkdir("$acl/newcerts", 0700);
chmod(0700, "$acl/newcerts");
&unlock_file("$acl/newcerts");
$miniserv{'ca'} = "$acl/ca.pem";
}

# list_themes()
# Returns an array of all installed themes
sub list_themes
{
local (@rv, $o);
opendir(DIR, $root_directory);
foreach $m (readdir(DIR)) {
	local %tinfo;
	next if ($m =~ /^\./);
	next if (!&read_file_cached("$root_directory/$m/theme.info", \%tinfo));
	next if (!&check_os_support(\%tinfo));
	foreach $o (@lang_order_list) {
		if ($tinfo{'desc_'.$o}) {
			$tinfo{'desc'} = $tinfo{'desc_'.$o};
			}
		}
	$tinfo{'dir'} = $m;
	push(@rv, \%tinfo);
	}
closedir(DIR);
return sort { lc($a->{'desc'}) cmp lc($b->{'desc'}) } @rv;
}

# install_webmin_module(file, unlink, nodeps, &users|groups)
# Installs a webmin module or theme, and returns either an error message
# or references to three arrays for descriptions, directories and sizes.
# On success or failure, the file is deleted if the unlink parameter is set.
sub install_webmin_module
{
local ($file, $need_unlink, $nodeps, $grant) = @_;
local (@mdescs, @mdirs, @msizes);
local (@newmods, $m);

# Uncompress the module file if needed
open(MFILE, $file);
read(MFILE, $two, 2);
close(MFILE);
if ($two eq "\037\235") {
	if (!&has_command("uncompress")) {
		unlink($file) if ($need_unlink);
		return &text('install_ecomp', "<tt>uncompress</tt>");
		}
	local $temp = $file =~ /\/([^\/]+)\.Z/i ? &tempname("$1")
						: &tempname();
	local $out = `uncompress -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_ecomp2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}
elsif ($two eq "\037\213") {
	if (!&has_command("gunzip")) {
		unlink($file) if ($need_unlink);
		return &text('install_egzip', "<tt>gunzip</tt>");
		}
	local $temp = $file =~ /\/([^\/]+)\.gz/i ? &tempname("$1")
						 : &tempname();
	local $out = `gunzip -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_egzip2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}
elsif ($two eq "BZ") {
	if (!&has_command("bunzip2")) {
		unlink($file) if ($need_unlink);
		return &text('install_ebunzip', "<tt>bunzip2</tt>");
		}
	local $temp = $file =~ /\/([^\/]+)\.gz/i ? &tempname("$1")
						 : &tempname();
	local $out = `bunzip2 -c "$file" 2>&1 >$temp`;
	unlink($file) if ($need_unlink);
	if ($?) {
		unlink($temp);
		return &text('install_ebunzip2', $out);
		}
	$file = $temp;
	$need_unlink = 1;
	}

# Check if this is an RPM webmin module or theme
local ($type, $redirect_to);
open(TYPE, "$root_directory/install-type");
chop($type = <TYPE>);
close(TYPE);
if ($type eq 'rpm' && $file =~ /\.rpm$/i &&
    ($out = `rpm -qp $file 2>/dev/null`)) {
	# Looks like an RPM of some kind, hopefully an RPM webmin module
	# or theme
	local ($out, %minfo, %tinfo);
	if ($out !~ /^(wbm|wbt)-([^\s\-]+)/) {
		unlink($file) if ($need_unlink);
		return $text{'install_erpm'};
		}
	$redirect_to = $name = $2;
	$out = &backquote_logged("rpm -U \"$file\" 2>&1");
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_eirpm', "<tt>$out</tt>");
		}

	$mdirs[0] = "$root_directory/$name";
	if (%minfo = &get_module_info($name)) {
		# Get the new module info
		$mdescs[0] = $minfo{'desc'};
		$msizes[0] = &disk_usage_kb($mdirs[0]);
		@newmods = ( $name );

		# Update the ACL for this user
		&grant_user_module($grant, [ $name ]);
		&webmin_log("install", undef, $name,
			    { 'desc' => $mdescs[0] });
		}
	elsif (%tinfo = &get_theme_info($name)) {
		# Get the theme info
		$mdescs[0] = $tinfo{'desc'};
		$msizes[0] = &disk_usage_kb($mdirs[0]);
		&webmin_log("tinstall", undef, $name,
			    { 'desc' => $mdescs[0] });
		}
	else {
		unlink($file) if ($need_unlink);
		return $text{'install_eneither'};
		}
	}
else {
	# Check if this is a valid module (a tar file of multiple module or
	# theme directories)
	local (%mods, %hasfile);
	local $tar = `tar tf "$file" 2>&1`;
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_etar', $tar);
		}
	foreach $f (split(/\n/, $tar)) {
		if ($f =~ /^\.\/([^\/]+)\/(.*)$/ || $f =~ /^([^\/]+)\/(.*)$/) {
			$redirect_to = $1 if (!$redirect_to);
			$mods{$1}++;
			$hasfile{$1,$2}++;
			}
		}
	foreach $m (keys %mods) {
		if (!$hasfile{$m,"module.info"} && !$hasfile{$m,"theme.info"}) {
			unlink($file) if ($need_unlink);
			return &text('install_einfo', "<tt>$m</tt>");
			}
		}
	if (!%mods) {
		unlink($file) if ($need_unlink);
		return $text{'install_enone'};
		}

	# Get the module.info files to check dependancies
	local $ver = &get_webmin_version();
	local $tmpdir = &tempname();
	mkdir($tmpdir, 0700);
	local $err;
	local @realmods;
	foreach $m (keys %mods) {
		next if (!$hasfile{$m,"module.info"});
		push(@realmods, $m);
		local %minfo;
		system("cd $tmpdir ; tar xf \"$file\" $m/module.info ./$m/module.info >/dev/null 2>&1");
		if (!&read_file("$tmpdir/$m/module.info", \%minfo)) {
			$err = &text('install_einfo', "<tt>$m</tt>");
			}
		elsif (!&check_os_support(\%minfo)) {
			$err = &text('install_eos', "<tt>$m</tt>",
				     $gconfig{'real_os_type'},
				     $gconfig{'real_os_version'});
			}
		elsif ($minfo{'usermin'} && !$minfo{'webmin'}) {
			$err = &text('install_eusermin', "<tt>$m</tt>");
			}
		elsif (!$nodeps) {
			foreach $dep (split(/\s+/, $minfo{'depends'})) {
				if ($dep =~ /^[0-9\.]+$/) {
					# Depends on some version of webmin
					if ($dep > $ver) {
						$err = &text('install_ever',
							"<tt>$m</tt>",
							"<tt>$dep</tt>");
						}
					}
				elsif ($dep =~ /^(\S+)\/([0-9\.]+)$/) {
					# Depends on a specific version of
					# some other module
					local ($dmod, $dver) = ($1, $2);
					local %dinfo = &get_module_info($dmod);
					if (!$mods{$dmod} &&
					    (!%dinfo ||
					     $dinfo{'version'} < $dver)) {
						$err = &text('install_edep2',
							"<tt>$m</tt>",
							"<tt>$dmod</tt>",
							"<tt>$dver</tt>");
						}
					}
				elsif (!-r "$root_directory/$dep/module.info" &&
				       !$mods{$dep}) {
					# Depends on some other module
					$err = &text('install_edep',
					        "<tt>$m</tt>", "<tt>$dep</tt>");
					}
				}
			foreach $dep (split(/\s+/, $minfo{'perldepends'})) {
				eval "use $dep";
				if ($@) {
					$err = &text('install_eperldep',
					     "<tt>$m</tt>", "<tt>$dep</tt>",
					     "$gconfig{'webprefix'}/cpan/download.cgi?source=3&cpan=$dep");
					}
				}
			}
		last if ($err);
		}
	system("rm -rf $tmpdir >/dev/null 2>&1");
	if ($err) {
		unlink($file) if ($need_unlink);
		return $err;
		}

	# Delete modules or themes being replaced
	local @grantmods;
	foreach $m (@realmods) {
		push(@grantmods, $m) if (!-d "$root_directory/$m");
		system("rm -rf '$root_directory/$m' 2>&1 >/dev/null") if ($m ne 'webmin');
		}

	# Extract all the modules and update perl path and ownership
	local $out = `cd $root_directory ; tar xf "$file" 2>&1 >/dev/null`;
	if ($?) {
		unlink($file) if ($need_unlink);
		return &text('install_eextract', $out);
		}
	if ($need_unlink) { unlink($file); }
	local $perl = &get_perl_path();
	local @st = stat("$module_root_directory/index.cgi");
	foreach $moddir (keys %mods) {
		local $pwd = "$root_directory/$moddir";
		if ($hasfile{$moddir,"module.info"}) {
			local %minfo = &get_module_info($moddir);
			push(@mdescs, $minfo{'desc'});
			push(@mdirs, $pwd);
			push(@msizes, &disk_usage_kb($pwd));
			&webmin_log("install", undef, $moddir,
				    { 'desc' => $minfo{'desc'} });
			push(@newmods, $moddir);
			}
		else {
			local %tinfo = &get_theme_info($moddir);
			push(@mdescs, $tinfo{'desc'});
			push(@mdirs, $pwd);
			push(@msizes, &disk_usage_kb($pwd));
			&webmin_log("tinstall", undef, $moddir,
				    { 'desc' => $tinfo{'desc'} });
			}
		system("cd $root_directory ; (find $pwd -name '*.cgi' ; find $pwd -name '*.pl') 2>/dev/null | $perl $root_directory/perlpath.pl $perl -");
		system("cd $root_directory ; chown -R $st[4]:$st[5] $pwd");
		}

	# Copy appropriate config file from modules to /etc/webmin
	system("cd $root_directory ; $perl $root_directory/copyconfig.pl '$gconfig{'os_type'}' '$gconfig{'os_version'}' '$root_directory' '$config_directory' ".join(' ', @realmods));

	# Update ACL for this user so they can access the new modules
	&grant_user_module($grant, \@grantmods);
	}
&flush_webmin_caches();

# Run post-install scripts
foreach $m (@newmods) {
	next if (!-r "$root_directory/$m/postinstall.pl");
	eval {
		&foreign_require($m, "postinstall.pl");
		&foreign_call($m, "module_install");
		};
	}

return [ \@mdescs, \@mdirs, \@msizes ];
}

# grant_user_module(&users/groups, &modules)
sub grant_user_module
{
# Grant to appropriate users
local %acl;
&read_acl(undef, \%acl);
open(ACL, ">".&acl_filename()); 
local $u;
foreach $u (keys %acl) {
	local @mods = @{$acl{$u}};
	if (!$_[0] || &indexof($u, @{$_[0]}) >= 0) {
		@mods = &unique(@mods, @{$_[1]});
		}
	print ACL "$u: ",join(' ', @mods),"\n";
	}
close(ACL);

# Grant to appropriate groups
if ($_[1] && &foreign_check("acl")) {
	&foreign_require("acl", "acl-lib.pl");
	local @groups = &acl::list_groups();
	local @users = &acl::list_users();
	local $g;
	foreach $g (@groups) {
		if (&indexof($g->{'name'}, @{$_[0]}) >= 0) {
			$g->{'modules'} = [ &unique(@{$g->{'modules'}},
					    	    @{$_[1]}) ];
			&acl::modify_group($g->{'name'}, $g);
			&acl::update_members(\@users, \@groups, $g->{'modules'},
					     $g->{'members'});
			}
		}
	}
}

# delete_webmin_module(module, [delete-acls])
# Deletes some webmin module, clone or theme, and return a description of
# the thing deleted.
sub delete_webmin_module
{
local $m = $_[0];
return undef if (!$m);
local %minfo = &get_module_info($m);
%minfo = &get_theme_info($m) if (!%minfo);
return undef if (!%minfo);
local ($mdesc, @aclrm);
@aclrm = ( $m ) if ($_[1]);
if ($minfo{'clone'}) {
	# Deleting a clone
	local %cinfo;
	&read_file("$config_directory/$m/clone", \%cinfo);
	unlink("$root_directory/$m");
	system("rm -rf $config_directory/$m");
	if ($gconfig{'theme'}) {
		unlink("$root_directory/$gconfig{'theme'}/$m");
		}
	$mdesc = &text('delete_desc1', $minfo{'desc'}, $minfo{'clone'});
	}
else {
	# Delete any clones of this module
	local @clones;
	local @mst = stat("$root_directory/$m");
	opendir(DIR, $root_directory);
	foreach $l (readdir(DIR)) {
		@lst = stat("$root_directory/$l");
		if (-l "$root_directory/$l" && $lst[1] == $mst[1]) {
			unlink("$root_directory/$l");
			system("rm -rf $config_directory/$l");
			push(@clones, $l);
			}
		}
	closedir(DIR);

	open(TYPE, "$root_directory/$m/install-type");
	chop($type = <TYPE>);
	close(TYPE);

	# Run the module's uninstall script
	if (&check_os_support(\%minfo) &&
	    -r "$root_directory/$m/uninstall.pl") {
		eval {
			&foreign_require($m, "uninstall.pl");
			&foreign_call($m, "module_uninstall");
			};
		}

	# Deleting the real module
	$pwd = "$root_directory/$m";
	local $size = &disk_usage_kb($pwd);
	$mdesc = &text('delete_desc2', "<b>$minfo{'desc'}</b>",
			   "<tt>$pwd</tt>", $size);
	if ($type eq 'rpm') {
		# This module was installed from an RPM .. rpm -e it
		&system_logged("rpm -e wbm-$m");
		}
	else {
		# Module was installed from a .wbm file .. just rm it
		&system_logged("rm -rf $root_directory/$m");
		}

	if ($_[1]) {
		# Delete any .acl files
		&system_logged("rm -f $config_directory/$m/*.acl");
		push(@aclrm, @clones);
		}
	}

# Delete from all users and groups
if (@aclrm) {
	&foreign_require("acl", "acl-lib.pl");
	local ($u, $g, $m);
	foreach $u (&acl::list_users()) {
		local $changed;
		foreach $m (@aclrm) {
			local $mi = &indexof($m, @{$u->{'modules'}});
			local $oi = &indexof($m, @{$u->{'ownmods'}});
			splice(@{$u->{'modules'}}, $mi, 1) if ($mi >= 0);
			splice(@{$u->{'ownmods'}}, $oi, 1) if ($oi >= 0);
			$changed++ if ($mi >= 0 || $oi >= 0);
			}
		&acl::modify_user($u->{'name'}, $u) if ($changed);
		}
	foreach $g (&acl::list_groups()) {
		local $changed;
		foreach $m (@aclrm) {
			local $mi = &indexof($m, @{$g->{'modules'}});
			local $oi = &indexof($m, @{$g->{'ownmods'}});
			splice(@{$g->{'modules'}}, $mi, 1) if ($mi >= 0);
			splice(@{$g->{'ownmods'}}, $oi, 1) if ($oi >= 0);
			$changed++ if ($mi >= 0 || $oi >= 0);
			}
		&acl::modify_group($g->{'name'}, $g) if ($changed);
		}
	}

&webmin_log("delete", undef, $m, { 'desc' => $minfo{'desc'} });
return $mdesc;
}

# file_basename(name)
sub file_basename
{
local $rv = $_[0];
$rv =~ s/^.*[\/\\]//;
return $rv;
}

# gnupg_setup()
# Setup gnupg so that rpms and .tar.gz files can be verified.
# Returns 0 if ok, 1 if gnupg is not installed, or 2 if something went wrong
# Assumes that gnupg-lib.pl is available
sub gnupg_setup
{
return ( 1, &text('enogpg', "<tt>gpg</tt>") ) if (!&has_command("gpg"));

# Check if we already have the key
local @keys = &list_keys();
foreach $k (@keys) {
	return ( 0 ) if ($k->{'email'}->[0] eq $webmin_key_email &&
		         &key_fingerprint($k) eq $webmin_key_fingerprint);
	}

# Import it if not
&list_keys();
$out = `gpg --import $module_root_directory/jcameron-key.asc 2>&1`;
if ($?) {
	return (2, $out);
	}
return 0;
}

# list_standard_modules()
# Returns a list containing the short names, URLs and descriptions of the
# standard Webmin modules from www.webmin.com. If an error occurs, returns the
# message instead.
sub list_standard_modules
{
local $temp = &tempname();
local $error;
local ($host, $port, $page, $ssl);
if ($config{'standard_url'}) {
	($host, $port, $page, $ssl) = &parse_http_url($config{'standard_url'});
	return $text{'standard_eurl'} if (!$host);
	}
else {
	($host, $port, $page, $ssl) = ($standard_host, $standard_port,
				       $standard_page, $standard_ssl);
	}
&http_download($host, $port, $page, $temp, \$error);
return $error if ($error);
local @rv;
open(TEMP, $temp);
while(<TEMP>) {
	s/\r|\n//g;
	local @l = split(/\t+/, $_);
	push(@rv, \@l);
	}
close(TEMP);
unlink($temp);
return \@rv;
}

# standard_chooser_button(input, [form])
sub standard_chooser_button
{
local $form = @_ > 1 ? $_[1] : 0;
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"standard_chooser.cgi?mod=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=600,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# list_third_modules()
# Returns a list containing the names, versions, URLs and descriptions of the
# third-party Webmin modules from thirdpartymodules.webmin.com. If an error
# occurs, returns the message instead.
sub list_third_modules
{
local $temp = &tempname();
local $error;
local ($host, $port, $page, $ssl);
if ($config{'third_url'}) {
	($host, $port, $page, $ssl) = &parse_http_url($config{'third_url'});
	return $text{'third_eurl'} if (!$host);
	}
else {
	($host, $port, $page, $ssl) = ($third_host, $third_port,
				       $third_page, $third_ssl);
	}
&http_download($host, $port, $page, $temp, \$error);
return $error if ($error);
local @rv;
open(TEMP, $temp);
while(<TEMP>) {
	s/\r|\n//g;
	local @l = split(/\t+/, $_);
	push(@rv, \@l);
	}
close(TEMP);
unlink($temp);
return \@rv;
}

# third_chooser_button(input, [form])
sub third_chooser_button
{
local $form = @_ > 1 ? $_[1] : 0;
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"third_chooser.cgi?mod=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=700,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"$text{'mods_thsel'}\">\n";
}

# get_webmin_base_version()
# Gets the webmin version, rounded to the nearest .01
sub get_webmin_base_version
{
return &base_version(&get_webmin_version());
}

# base_version()
# Rounds a version number down to the nearest .01
sub base_version
{
return sprintf("%.2f0", $_[0] - 0.005);
}

$newmodule_users_file = "$config_directory/newmodules";

# get_newmodule_users()
# Returns a ref to an array of users to whom new modules are granted, or undef
sub get_newmodule_users
{
if (open(NEWMODS, $newmodule_users_file)) {
	local @rv;
	while(<NEWMODS>) {
		s/\r|\n//g;
		push(@rv, $_) if (/\S/);
		}
	close(NEWMODS);
	return \@rv;
	}
else {
	return undef;
	}
}

# save_newmodule_users(&users)
# Saves the list of users to whom new modules are granted. If undef is given,
# the default behavious is used
sub save_newmodule_users
{
&lock_file($newmodule_users_file);
if ($_[0]) {
	open(NEWMODS, ">$newmodule_users_file");
	foreach $u (@{$_[0]}) {
		print NEWMODS "$u\n";
		}
	close(NEWMODS);
	}
else {
	unlink($newmodule_users_file);
	}
&unlock_file($newmodule_users_file);
}

# get_miniserv_sockets(&miniserv)
sub get_miniserv_sockets
{
local @sockets;
push(@sockets, [ $_[0]->{'bind'} || "*", $_[0]->{'port'} ]);
foreach $s (split(/\s+/, $_[0]->{'sockets'})) {
	if ($s =~ /^(\d+)$/) {
		# Just listen on another port on the main IP
		push(@sockets, [ $sockets[0]->[0], $s ]);
		}
	elsif ($s =~ /^(\S+):(\d+)$/) {
		# Listen on a specific port and IP
		push(@sockets, [ $1, $2 ]);
		}
	elsif ($s =~ /^([0-9\.]+):\*$/ || $s =~ /^([0-9\.]+)$/) {
		# Listen on the main port on another IP
		push(@sockets, [ $1, "*" ]);
		}
	}
return @sockets;
}

1;
