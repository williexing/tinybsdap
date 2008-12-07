# init-lib.pl
# Common functions for SYSV-style boot/shutdown sequences.
# These functions assume that under a directory (like /etc/ or /etc/rc.d/)
# there is a directory called rcX.d for each runlevel X. In each runlevel
# directory is a list of files with names like S64foobar or K99smeg, where
# the first letter is S (for commands run at boot time) or K (shutdown time),
# the next 2 digits the execution order and the rest the action name.
#
# Typically, each runlevel file is linked (hard or soft) to a file in
# the directory init.d. Each file in init.d may have several links to it from
# different runlevels (for startup and shutdown). However, some runlevel
# files may not be links at all.

do '../web-lib.pl';
&init_config();
require '../ui-lib.pl';

# runlevel_actions(level, S|K)
# Return a list of actions started or stopped in some run-level, each in
# the format:
#  number name inode
sub runlevel_actions
{
local($dir, $f, @stbuf, @rv);
$dir = "$config{init_base}/rc$_[0].d";
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f !~ /^([A-Z])(\d+)(.*)$/ || $1 ne $_[1]) { next; }
	if (!(@stbuf = stat("$dir/$f"))) { next; }
	push(@rv, "$2 $3 $stbuf[1]");
	}
closedir(DIR);
@rv = sort { @a = split(/\s/,$a); @b = split(/\s/,$b); $a[0] <=> $b[0]; } @rv;
return $_[1] eq "S" ? @rv : reverse(@rv);
}


# list_runlevels()
# Returns a list of known runlevels
sub list_runlevels
{
local(@rv);
opendir(DIR, $config{init_base});
foreach (readdir(DIR)) {
	if (/^rc([A-z0-9])\.d$/) {
		#if (!$config{show_opts} && $1 < 1) { next; }
		push(@rv, $1);
		}
	}
closedir(DIR);
return sort(@rv);
}


# list_actions()
# List boot time actions from init.d
sub list_actions
{
local($dir, $f, @stbuf, @rv);
$dir = $config{init_dir};
opendir(DIR, $dir);
foreach $f (sort { lc($a) cmp lc($b) } readdir(DIR)) {
	if ($f eq "." || $f eq ".." || $f =~ /\.bak$/ || $f eq "functions" ||
	    $f eq "core" || $f eq "README" || $f eq "rc" || $f eq "rcS" ||
	    -d "$dir/$f" || $f =~ /\.swp$/ || $f eq "skeleton" ||
	    $f =~ /\.lock$/ || $f =~ /\.dpkg-(old|dist)$/) { next; }
	if (@stbuf = stat("$dir/$f")) {
		push(@rv, "$f $stbuf[1]");
		}
	}
closedir(DIR);
foreach $f (split(/\s+/, $config{'extra_init'})) {
	if (@stbuf = stat($f)) {
		push(@rv, "$f $stbuf[1]");
		}
	}
return @rv;
}


# action_levels(S|K, action)
# Return a list of run levels in which some action (from init.d) is started
# or stopped. Each item is in the format:
#  level order name
sub action_levels
{
local(@stbuf, $rl, $dir, $f, @stbuf2, @rv);
@stbuf = stat(&action_filename($_[1]));
foreach $rl (&list_runlevels()) {
	$dir = "$config{init_base}/rc$rl.d";
	opendir(DIR, $dir);
	foreach $f (readdir(DIR)) {
		if ($f =~ /^([A-Z])(\d+)(.*)$/ && $1 eq $_[0]) {
			@stbuf2 = stat("$dir/$f");
			if ($stbuf[1] == $stbuf2[1]) {
				push(@rv, "$rl $2 $3");
				last;
				}
			}
		}
	closedir(DIR);
	}
return @rv;
}


# action_filename(name)
# Returns the name of the file in init.d for some action
sub action_filename
{
return $_[0] =~ /^\// ? $_[0] : "$config{init_dir}/$_[0]";
}


# runlevel_filename(level, S|K, order, name)
sub runlevel_filename
{
local $n = $_[3];
$n =~ s/^(.*)\///;
return "$config{init_base}/rc$_[0].d/$_[1]$_[2]$n";
}


# add_rl_action(action, runlevel, S|K, order)
# Add some existing action to a runlevel
sub add_rl_action
{
$file = &runlevel_filename($_[1], $_[2], $_[3], $_[0]);
while(-r $file) {
	if ($file =~ /^(.*)_(\d+)$/) { $file = "$1_".($2+1); }
	else { $file = $file."_1"; }
	}
&lock_file($file);
if ($config{soft_links}) {
	symlink(&action_filename($_[0]), $file);
	}
else {
	link(&action_filename($_[0]), $file);
	}
&unlock_file($file);
}


# delete_rl_action(name, runlevel, S|K)
# Delete some action from a runlevel
sub delete_rl_action
{
local(@stbuf, $dir, $f, @stbuf2);
@stbuf = stat(&action_filename($_[0]));
$dir = "$config{init_base}/rc$_[1].d";
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^([A-Z])(\d+)(.+)$/ && $1 eq $_[2]) {
		@stbuf2 = stat("$dir/$f");
		if ($stbuf[1] == $stbuf2[1]) {
			# found file to delete.. unlink
			&lock_file("$dir/$f");
			unlink("$dir/$f");
			&unlock_file("$dir/$f");
			last;
			}
		}
	}
closedir(DIR);
}


# reorder_rl_action(name, runlevel, S|K, new_order)
sub reorder_rl_action
{
local(@stbuf, $dir, $f, @stbuf2);
@stbuf = stat(&action_filename($_[0]));
$dir = "$config{init_base}/rc$_[1].d";
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^([A-Z])(\d+)(.+)$/ && $1 eq $_[2]) {
		@stbuf2 = stat("$dir/$f");
		if ($stbuf[1] == $stbuf2[1]) {
			# Found file that needs renaming
			$file = "$config{init_base}/rc$_[1].d/$1$_[3]$3";
			while(-r $file) {
				if ($file =~ /^(.*)_(\d+)$/)
					{ $file = "$1_".($2+1); }
				else { $file = $file."_1"; }
				}
			&rename_logged("$dir/$f", $file);
			last;
			}
		}
	}
closedir(DIR);
}


# rename_action(old, new)
# Change the name of an action in init.d, and re-direct all soft links
# to it from the runlevel directories
sub rename_action
{
local($file, $idx, $old);
foreach (&action_levels('S', $_[0])) {
	/^(\S+)\s+(\S+)\s+(\S+)$/;
	$file = "$config{init_base}/rc$1.d/S$2$3";
	if (readlink($file)) {
		# File is a symbolic link.. change it
		&lock_file($file);
		unlink($file);
		symlink("$config{init_dir}/$_[1]", $file);
		&unlock_file($file);
		}
	if (($idx = index($file, $_[0])) != -1) {
		$old = $file;
		substr($file, $idx, length($_[0])) = $_[1];
		&rename_logged($old, $file);
		}
	}
foreach (&action_levels('K', $_[0])) {
	/^(\S+)\s+(\S+)\s+(\S+)$/;
	$file = "$config{init_base}/rc$1.d/K$2$3";
	if (readlink($file)) {
		# File is a symbolic link.. change it
		&lock_file($file);
		unlink($file);
		symlink("$config{init_dir}/$_[1]", $file);
		&unlock_file($file);
		}
	if (($idx = index($file, $_[0])) != -1) {
		$old = $file;
		substr($file, $idx, length($_[0])) = $_[1];
		&rename_logged($old, $file);
		}
	}
&rename_logged("$config{init_dir}/$_[0]", "$config{init_dir}/$_[1]");
}


# rename_rl_action(runlevel, S|K, order, old, new)
# Change the name of a runlevel file
sub rename_rl_action
{
&rename_logged("$config{init_base}/rc$_[0].d/$_[1]$_[2]$_[3]",
               "$config{init_base}/rc$_[0].d/$_[1]$_[2]$_[4]");
}

# get_inittab_runlevel()
# Returns the runlevels entered at boot time. If more than one is returned,
# actions from all of them are used!
sub get_inittab_runlevel
{
local %iconfig = &foreign_config("inittab");
local @rv;
local $id = $config{'inittab_id'};
open(TAB, $iconfig{'inittab_file'});
while(<TAB>) {
	if (/^$id:(\d+):/) { @rv = ( $1 ); }
	}
close(TAB);
if ($config{"inittab_rl_$rv[0]"}) {
	@rv = split(/,/, $config{"inittab_rl_$rv[0]"});
	}
return @rv;
}

# init_description(file, \%hasargs)
sub init_description
{
open(FILE, $_[0]);
local @lines = <FILE>;
close(FILE);
local $data = join("", @lines);
if ($_[1]) {
	foreach (@lines) {
		if (/^\s*(['"]?)([a-z]+)\1\)/i) {
			$_[1]->{$2}++;
			}
		}
	}

local $desc;
if ($config{'daemons_dir'}) {
	# First try the daemons file
	local %daemon;
	if ($_[0] =~ /\/([^\/]+)$/ &&
	    &read_env_file("$config{'daemons_dir'}/$1", \%daemon) &&
	    $daemon{'DESCRIPTIVE'}) {
		return $daemon{'DESCRIPTIVE'};
		}
	}
if ($config{'chkconfig'}) {
	# Find the redhat-style description: section
	foreach (@lines) {
		s/\r|\n//g;
		if (/^#+\s*description:(.*?)(\\?$)/) {
			$desc = $1;
			}
		elsif (/^#+\s*(.*?)(\\?$)/ && $desc && $1) {
			$desc .= "\n".$1;
			}
		if ($desc && !$2) {
			last;
			}
		}
	}
elsif ($config{'init_info'} || $data =~ /BEGIN INIT INFO/) {
	# Find the suse-style Description: line
	foreach (@lines) {
		s/\r|\n//g;
		if (/^#\s*Description:\s*(.*)/) {
			$desc = $1;
			}
		}
	}
else {
	# Use the first comments
	foreach (@lines) {
		s/\r|\n//g;
		next if (/^#!\s*\/(bin|sbin|usr)\// || /\$id/i || /^#+\s+@/ ||
			 /source function library/i || /^#+\s*copyright/i);
		if (/^#+\s*(.*)/) {
			last if ($desc && !$1);
			$desc .= $1."\n" if ($1);
			}
		elsif (/\S/) { last; }
		}
	$_[0] =~ /\/([^\/]+)$/;
	$desc =~ s/^Tag\s+(\S+)\s*//i;
	$desc =~ s/^\s*$1\s+//;
	}
return $desc;
}

# chkconfig_info(file)
# If a file has a chkconfig: section specifying the runlevels to start in and
# the orders to use, return them
sub chkconfig_info
{
local @rv;
open(FILE, $_[0]);
while(<FILE>) {
	if (/^#\s*chkconfig:\s+(\S+)\s+(\d+)\s+(\d+)/) {
		@rv = ( $1 eq '-' ? [ ] : [ split(//, $1) ], $2, $3 );
		}
	}
close(FILE);
return @rv;
}

# action_status(action)
# Returns 0 if some action doesn't exist, 1 if it does but is not enabled,
# or 2 if it exists and is enabled
sub action_status
{
if ($config{'init_base'}) {
	# Look for init script
	local ($a, $exists, $starting, %daemon);
	foreach $a (&list_actions()) {
		local @a = split(/\s+/, $a);
		if ($a[0] eq $_[0]) {
			$exists++;
			local @boot = &get_inittab_runlevel();
			foreach $s (&action_levels("S", $a[0])) {
				local ($l, $p) = split(/\s+/, $s);
				$starting++ if (&indexof($l, @boot) >= 0);
				}
			}
		}
	if ($starting && $config{'daemons_dir'} &&
	    &read_env_file("$config{'daemons_dir'}/$_[0]", \%daemon)) {
		$starting = lc($daemon{'ONBOOT'}) eq 'yes' ? 1 : 0;
		}
	return !$exists ? 0 : $starting ? 2 : 1;
	}
else {
	# Look for entry in rc.local
	local $fn = "$module_config_directory/$_[0].sh";
	local $cmd = "$fn start";
	open(LOCAL, $config{'local_script'});
	while(<LOCAL>) {
		s/\r|\n//g;
		$found++ if ($_ eq $cmd);
		}
	close(LOCAL);
	return $found && -r $fn ? 2 : -r $fn ? 1 : 0;
	}
}

# enable_at_boot(action, description, startcode, stopcode, statuscode)
# Makes some action start at boot time, creating the script by copying the
# specified file if necessary
sub enable_at_boot
{
local $st = &action_status($_[0]);
return if ($st == 2);	# already starting!
local ($daemon, %daemon);

if ($config{'daemons_dir'} &&
    &read_env_file("$config{'daemons_dir'}/$_[0]", \%daemon)) {
	$daemon++;
	}
local $fn;
if ($config{'init_base'}) {
	# Normal init.d system
	$fn = &action_filename($_[0]);
	}
else {
	# Need to create hack init script
	$fn = "$module_config_directory/$_[0].sh";
	}
local @chk = &chkconfig_info($fn);
local @start = @{$chk[0]} ? @{$chk[0]} : &get_start_runlevels();
local $start_order = $chk[1] || "9" x $config{'order_digits'};
local $stop_order = $chk[2] || "9" x $config{'order_digits'};
local @stop;
if (@chk) {
	local %starting = map { $_, 1 } @start;
	@stop = grep { !$starting{$_} && /^\d+$/ } &list_runlevels();
	}

local $need_links = 0;
if ($st == 1 && $daemon) {
	# Just update daemons file
	$daemon{'ONBOOT'} = 'yes';
	&lock_file("$config{'daemons_dir'}/$_[0]");
	&write_env_file("$config{'daemons_dir'}/$_[0]", \%daemon);
	&unlock_file("$config{'daemons_dir'}/$_[0]");
	}
elsif ($st == 1) {
	# Just need to create links (later)
	$need_links++;
	}
elsif ($_[1]) {
	# Need to create the init script
	&lock_file($fn);
	open(ACTION, ">$fn");
	print ACTION "#!/bin/sh\n";
	if ($config{'chkconfig'}) {
		# Redhat-style description: and chkconfig: lines
		print ACTION "# description: $_[1]\n";
		print ACTION "# chkconfig: $config{'chkconfig'} ",
			     "$start_order $stop_order\n";
		}
	elsif ($config{'init_info'}) {
		# Suse-style init info section
		print ACTION "### BEGIN INIT INFO\n",
			     "# Provides: $_[0]\n",
			     "# Required-Start: \$network \$syslog\n",
			     "# Required-Stop: \$network\n",
			     "# Default-Start: ",join(" ", @start),"\n",
			     "# Description: $_[1]\n",
			     "### END INIT INFO\n";
		}
	else {
		print ACTION "# $_[1]\n";
		}
	print ACTION "\n";
	print ACTION "case \"\$1\" in\n";

	if ($_[2]) {
		print ACTION "'start')\n";
		print ACTION &tab_indent($_[2]);
		print ACTION "\tRETVAL=\$?\n";
		if ($config{'subsys'}) {
			print ACTION "\tif [ \"\$RETVAL\" = \"0\" ]; then\n";
			print ACTION "\t\ttouch $config{'subsys'}/$_[0]\n";
			print ACTION "\tfi\n";
			}
		print ACTION "\t;;\n";
		}

	if ($_[3]) {
		print ACTION "'stop')\n";
		print ACTION &tab_indent($_[3]);
		print ACTION "\tRETVAL=\$?\n";
		if ($config{'subsys'}) {
			print ACTION "\tif [ \"\$RETVAL\" = \"0\" ]; then\n";
			print ACTION "\t\trm -f $config{'subsys'}/$_[0]\n";
			print ACTION "\tfi\n";
			}
		print ACTION "\t;;\n";
		}

	if ($_[4]) {
		print ACTION "'status')\n";
		print ACTION &tab_indent($_[4]);
		print ACTION "\t;;\n";
		}

	if ($_[2] && $_[3]) {
		print ACTION "'restart')\n";
		print ACTION "\t\$0 stop && \$0 start\n";
		print ACTION "\tRETVAL=\$?\n";
		print ACTION "\t;;\n";
		}

	print ACTION "*)\n";
	print ACTION "\techo \"Usage: \$0 { start | stop }\"\n";
	print ACTION "\tRETVAL=1\n";
	print ACTION "\t;;\n";
	print ACTION "esac\n";
	print ACTION "exit \$RETVAL\n";
	close(ACTION);
	chmod(0755, $fn);
	&unlock_file($fn);
	$need_links++;
	}

if ($need_links) {
	if ($config{'init_base'}) {
		# Just link up the init script
		local $s;
		foreach $s (@start) {
			&add_rl_action($_[0], $s, "S", $start_order);
			}
		foreach $s (@stop) {
			&add_rl_action($_[0], $s, "K", $stop_order);
			}
		}
	else {
		# Just add rc.local entry
		local $lref = &read_file_lines($config{'local_script'});
		local $i;
		for($i=0; $i<@$lref && $lref->[$i] !~ /^exit\s/; $i++) { }
		splice(@$lref, $i, 0, "$fn start");
		if ($config{'local_down'}) {
			# Also add to shutdown script
			$lref = &read_file_lines($config{'local_down'});
			for($i=0; $i<@$lref &&
				  $lref->[$i] !~ /^exit\s/; $i++) { }
			splice(@$lref, $i, 0, "$fn stop");
			}
		&flush_file_lines();
		}
	}
}

# disable_at_boot(action)
# Turns off some action from starting at boot
sub disable_at_boot
{
local $st = &action_status($_[0]);
return if ($st != 2);	# not currently starting

if ($config{'init_base'}) {
	# Unlink or disable init script
	local ($daemon, %daemon);
	local $file = &action_filename($_[0]);
	local @chk = &chkconfig_info($file);

	if ($config{'daemons_dir'} &&
	    &read_env_file("$config{'daemons_dir'}/$_[0]", \%daemon)) {
		# Update daemons file
		$daemon{'ONBOOT'} = 'no';
		&lock_file("$config{'daemons_dir'}/$_[0]");
		&write_env_file("$config{'daemons_dir'}/$_[0]", \%daemon);
		&unlock_file("$config{'daemons_dir'}/$_[0]");
		}
	else {
		# Just unlink the S links
		foreach (&action_levels('S', $_[0])) {
			/^(\S+)\s+(\S+)\s+(\S+)$/;
			&delete_rl_action($_[0], $1, 'S');
			}

		if (@chk) {
			# Take out the K links as well, since we know how to put
			# them back from the chkconfig info
			foreach (&action_levels('K', $_[0])) {
				/^(\S+)\s+(\S+)\s+(\S+)$/;
				&delete_rl_action($_[0], $1, 'K');
				}
			}
		}
	}
else {
	# Take out of rc.local file
	local $lref = &read_file_lines($config{'local_script'});
	local $cmd = "$module_config_directory/$_[0].sh start";
	local $i;
	for($i=0; $i<@$lref; $i++) {
		if ($lref->[$i] eq $cmd) {
			splice(@$lref, $i, 1);
			last;
			}
		}
	if ($config{'local_down'}) {
		# Take out of shutdown script
		$lref = &read_file_lines($config{'local_down'});
		local $cmd = "$module_config_directory/$_[0].sh stop";
		for($i=0; $i<@$lref; $i++) {
			if ($lref->[$i] eq $cmd) {
				splice(@$lref, $i, 1);
				last;
				}
			}
		}
	&flush_file_lines();
	}
}

# tab_indent(lines)
sub tab_indent
{
local ($rv, $l);
foreach $l (split(/\n/, $_[0])) {
	$rv .= "\t$l\n";
	}
return $rv;
}

# get_start_runlevels()
# Returns a list of runlevels that actions should be started in
sub get_start_runlevels
{
if ($config{'boot_levels'}) {
	return split(/[ ,]+/, $config{'boot_levels'});
	}
else {
	local @boot = &get_inittab_runlevel();
	return ( $boot[0] );
	}
}

1;

