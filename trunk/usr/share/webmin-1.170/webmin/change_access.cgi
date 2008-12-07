#!/usr/local/bin/perl
# change_access.cgi
# Update IP allow and deny parameters

require './webmin-lib.pl';
use Socket;
&ReadParse();
&error_setup($text{'access_err'});

$raddr = $ENV{'REMOTE_ADDR'};
if ($in{"access"}) {
	@hosts = split(/\s+/, $in{"ip"});
	if (!@hosts) { &error($text{'access_enone'}); }
	foreach $h (@hosts) {
		if ($h =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
			&check_ipaddress($1) ||
				&error(&text('access_enet', "$1"));
			&check_ipaddress($2) ||
				&error(&text('access_emask', "$2"));
			$i = $h;
			}
		elsif ($h =~ /^[0-9\.]+$/) {
			&check_ipaddress($h) ||
				&error(&text('access_eip', $h));
			$i = $h;
			}
		elsif ($h =~ /^\*\.(\S+)$/) {
			$i = $h;
			}
		elsif ($h eq 'LOCAL') {
			$i = 'LOCAL';
			}
		elsif (!($i = join('.', unpack("CCCC", inet_aton($h))))) {
			&error(&text('access_ehost', $h));
			}
		push(@ip, $i);
		}
	if ($in{"access"} == 1 && !&ip_match($raddr, @ip) ||
	    $in{"access"} == 2 && &ip_match($raddr, @ip)) {
		&error(&text('access_eself', $raddr));
		}
	}

eval "use Authen::Libwrap qw(hosts_ctl STRING_UNKNOWN)";
if (!$@ && $in{'libwrap'}) {
	# Check if the current address would be denied
	if (!hosts_ctl("webmin", STRING_UNKNOWN, $raddr, STRING_UNKNOWN)) {
		&error(&text('access_eself', $raddr));
		}
	}

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
delete($miniserv{"allow"});
delete($miniserv{"deny"});
if ($in{"access"} == 1) { $miniserv{"allow"} = join(' ', @hosts); }
elsif ($in{"access"} == 2) { $miniserv{"deny"} = join(' ', @hosts); }
$miniserv{'libwrap'} = $in{'libwrap'};
$miniserv{'alwaysresolve'} = $in{'alwaysresolve'};
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&restart_miniserv();
&webmin_log("access", undef, undef, \%in);
&redirect("");

# ip_match(ip, [match]+)
# Checks an IP address against a list of IPs, networks and networks/masks
sub ip_match
{
local(@io, @mo, @ms, $i, $j);
@io = split(/\./, $_[0]);
local $hn = gethostbyaddr(inet_aton($_[0]), AF_INET);
undef($hn) if ((&to_ipaddress($hn))[0] ne $_[0]);
for($i=1; $i<@_; $i++) {
	local $mismatch = 0;
	if ($_[$i] =~ /^(\S+)\/(\S+)$/) {
		# Compare with network/mask
		@mo = split(/\./, $1); @ms = split(/\./, $2);
		for($j=0; $j<4; $j++) {
			if ((int($io[$j]) & int($ms[$j])) != int($mo[$j])) {
				$mismatch = 1;
				}
			}
		}
	elsif ($_[$i] =~ /^\*(\.\S+)$/) {
		# Compare with hostname regexp
		$mismatch = 1 if ($hn !~ /$1$/);
		}
	elsif ($_[$i] eq 'LOCAL') {
		# Just assume OK for now
		}
	else {
		# Compare with IP or network
		@mo = split(/\./, $_[$i]);
		while(@mo && !$mo[$#mo]) { pop(@mo); }
		for($j=0; $j<@mo; $j++) {
			if ($mo[$j] != $io[$j]) {
				$mismatch = 1;
				}
			}
		}
	return 1 if (!$mismatch);
	}
return 0;
}

