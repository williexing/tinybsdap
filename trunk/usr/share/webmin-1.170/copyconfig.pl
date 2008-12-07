#!/usr/bin/perl
# copyconfig.pl
# Copy the appropriate config file for each module into the webmin config
# directory. If it is already there, merge in new directives. Called with
# <osname> <osversion> <install dir> <config dir> <module>+

@ARGV >= 4 || die "usage: copyconfig.pl <os> <version> <webmin-dir> <config-dir> [module ...]";
$os = $ARGV[0];
$ver = $ARGV[1];
$wadir = $ARGV[2];
$confdir = $ARGV[3];

# Find all clones
opendir(DIR, $wadir);
foreach $f (readdir(DIR)) {
	if (readlink("$wadir/$f")) {
		@st = stat("$wadir/$f");
		push(@{$clone{$st[1]}}, $f);
		}
	}
closedir(DIR);

# For each module, copy its config to itself and all clones
@mods = @ARGV[4..$#ARGV];
foreach $m (@mods) {
	# Find any range-number config files
	$srcdir = "$wadir/$m";
	$rangefile = undef;
	opendir(DIR, $srcdir);
	while($f = readdir(DIR)) {
		if ($f =~ /^config\-\Q$os\E\-([0-9\.]+)\-([0-9\.]+)$/ &&
		    $ver >= $1 && $ver <= $2) {
			$rangefile = "$srcdir/$f";
			}
		elsif ($f =~ /^config\-\Q$os\E\-([0-9\.]+)\-\*$/ &&
		       $ver >= $1) {
			$rangefile = "$srcdir/$f";
			}
		elsif ($f =~ /^config\-\Q$os\E\-\*\-([0-9\.]+)$/ &&
		       $ver <= $1) {
			$rangefile = "$srcdir/$f";
			}
		}
	closedir(DIR);

	# Find the best-matching config file
	if (-r "$srcdir/config-$os-$ver") {
		$conf = "$srcdir/config-$os-$ver";
		}
	elsif ($rangefile) {
		$conf = $rangefile;
		}
	elsif (-r "$srcdir/config-$os") {
		$conf = "$srcdir/config-$os";
		}
	elsif ($os =~ /^(\S+)-(\S+)$/ && -r "$srcdir/config-*-$2") {
		$conf = "$srcdir/config-*-$2";
		}
	elsif (-r "$srcdir/config") {
		$conf = "$srcdir/config";
		}
	else {
		$conf = "/dev/null";
		}

	@st = stat($srcdir);
	@copyto = ( @{$clone{$st[1]}}, $m );
	foreach $c (@copyto) {
		mkdir("$confdir/$c", 0755);
		undef(%oldconf); undef(%newconf);
		&read_file("$confdir/$c/config", \%oldconf);
		&read_file($conf, \%newconf);
		foreach $k (keys %oldconf) {
			$newconf{$k} = $oldconf{$k};
			}
		&write_file("$confdir/$c/config", \%newconf);
		}
	}

# read_file(file, array)
# Fill an associative array with name=value pairs from a file
sub read_file
{
local($arr);
$arr = $_[1];
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	s/\r|\n//g;
        if (!/^#/ && /^([^=]+)=(.*)$/) { $$arr{$1} = $2; }
        }
close(ARFILE);
return 1;
}
 
# write_file(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file
{
local($arr);
$arr = $_[1];
open(ARFILE, "> $_[0]");
foreach $k (keys %$arr) {
        print ARFILE "$k=$$arr{$k}\n";
        }
close(ARFILE);
}
