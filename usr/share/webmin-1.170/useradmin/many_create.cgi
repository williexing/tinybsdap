#!/usr/local/bin/perl
# many_create.cgi
# Create multiple users from an uploaded text file

require './user-lib.pl';
&ReadParseMime();
if ($in{'file'}) {
	$data = $in{'file'};
	}
elsif ($in{'local'}) {
	open(LOCAL, $in{'local'}) || &error($text{'many_elocal'});
	while(<LOCAL>) {
		$data .= $_;
		}
	close(LOCAL);
	}
else {
	&error($text{'many_efile'});
	}

&ui_print_header(undef, $text{'many_title'}, "");
$| = 1;

# Work out a good base UID
&lock_user_files();
&my_setpwent();
while(@tmp = &my_getpwent()) {
	$used{$tmp[2]}++;
	$taken{$tmp[0]}++;
	}
&my_endpwent();
$newuid = int($config{'base_uid'});

# Work out a good base GID
&my_setgrent();
while(@tmp = &my_getgrent()) {
	$gused{$tmp[2]}++;
	$gtaken{$tmp[0]}++;
	}
&my_endgrent();
$newgid = int($config{'base_gid'});

print "<pre>\n";
$lnum = 0;
foreach $line (split(/[\r\n]+/, $data)) {
	$lnum++;
	local @line = split(/:/, $line, -1);
	local %user;
	if (&passfiles_type() == 2) {
		# SYSV-style passwd and shadow information
		if (@line != 12) {
			print &text('many_elen', $lnum, 12),"\n";
			next;
			}
		$user{'min'} = $line[7];
		$user{'max'} = $line[8];
		$user{'warn'} = $line[9];
		$user{'inactive'} = $line[10];
		$user{'expire'} = $line[11];
		$user{'change'} = int(time() / (60*60*24));
		}
	elsif (&passfiles_type() == 1) {
		# BSD master.passwd information
		if (@line != 10) {
			print &text('many_elen', $lnum, 10),"\n";
			next;
			}
		$user{'class'} = $line[7];
		$user{'change'} = $line[8];
		$user{'expire'} = $line[9];
		}
	else {
		# Classic passwd file information
		if (@line != 7) {
			print &text('many_elen', $lnum, 7),"\n";
			next;
			}
		}

	# Parse common fields
	if (!$line[0]) {
		print &text('many_eline', $lnum),"\n";
		next;
		}
	$user{'user'} = $line[0];
	if ($taken{$user{'user'}}) {
		print &text('many_euser', $lnum, $user{'user'}),"\n";
		next;
		}
	if ($line[2] !~ /^\d+$/) {
		# make up a UID
		while($used{$newuid}) {
			$newuid++;
			}
		$user{'uid'} = $newuid;
		}
	else {
		# use the given UID!!
		$user{'uid'} = $line[2];
		}
	$used{$user{'uid'}}++;
	if ($line[5] !~ /^\//) {
		print &text('many_ehome', $lnum, $line[5]),"\n";
		next;
		}
	$user{'home'} = $line[5];
	if (!-r $line[6]) {
		print &text('many_eshell', $lnum, $line[6]),"\n";
		next;
		}
	$user{'shell'} = $line[6];
	$user{'real'} = $line[4];
	if ($line[3] !~ /^\d+$/) {
		# Need to create a new group for the user
		if ($gtaken{$user{'user'}}) {
			print &text('many_egtaken', $lnum, $user{'user'}),"\n";
			next;
			}
		while($gused{$newgid}) {
			$newgid++;
			}
		local %group;
		$group{'group'} = $user{'user'};
		$user{'gid'} = $group{'gid'} = $newgid;
		&create_group(\%group);
		}
	else {
		$user{'gid'} = $line[3];
		}

	# Create the user!
	if ($in{'makehome'} && !-d $user{'home'}) {
		if (!mkdir($user{'home'}, oct($config{'homedir_perms'}))) {
			print &text('many_emkdir', $user{'home'}, $!),"\n";
			}
		chmod(oct($config{'homedir_perms'}), $user{'home'});
		chown($user{'uid'}, $user{'gid'}, $user{'home'});
		}
	if ($line[1] eq 'x') {
		# No login allowed
		$user{'pass'} = $config{'lock_string'};
		$user{'passmode'} = 1;
		}
	elsif ($line[1] eq '') {
		# No password needed
		$user{'pass'} = '';
		$user{'passmode'} = 0;
		}
	else {
		# Normal password
		$salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
		$user{'pass'} = crypt($line[1], $salt);
		$user{'passmode'} = 3;
		$user{'plainpass'} = $line[1];
		}
	&create_user(\%user);
	&other_modules("useradmin_create_user", \%user);

	if ($in{'copy'} && $in{'makehome'}) {
		# Copy files to user's home directory
		local $uf = $config{'user_files'};
		if ($group = &my_getgrgid($user{'gid'})) {
			$uf =~ s/\$group/$group/g;
			}
		$uf =~ s/\$gid/$user{'gid'}/g;
		&copy_skel_files($uf, $user{'home'},
				 $user{'uid'}, $user{'gid'});
		}

	print "<b>",&text('many_ok',$user{'user'}),"</b>\n";
	}
print "</pre>\n";
&unlock_user_files();

&ui_print_footer("", $text{'index_return'});

