#!/usr/local/bin/perl
# change_os.cgi
# Change OS settings

require './webmin-lib.pl';
&ReadParse();

&lock_file("$config_directory/config");
@os = split(/,/, $in{'os'});
$gconfig{'real_os_type'} = $os[0];
$gconfig{'real_os_version'} = $os[1];
$gconfig{'os_type'} = $os[2];
$gconfig{'os_version'} = $os[3];
$gconfig{'path'} = join(":", split(/[\r\n]+/, $in{'path'}));
$gconfig{'ld_path'} = join(":", split(/[\r\n]+/, $in{'ld_path'}));
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
foreach $e (keys %miniserv) {
	delete($miniserv{$e}) if ($e =~ /^env_(\S+)$/ &&
				  $1 ne "WEBMIN_CONFIG" && $1 ne "WEBMIN_VAR");
	}
for($i=0; defined($n = $in{"name_$i"}); $i++) {
	next if (!$n);
	$miniserv{'env_'.$n} = $in{"value_$i"}
		if ($n ne "WEBMIN_CONFIG" && $n ne "WEBMIN_VAR");
	}
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&restart_miniserv();

&webmin_log("os", undef, undef, \%in);
&redirect("");
