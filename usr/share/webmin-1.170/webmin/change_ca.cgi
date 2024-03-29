#!/usr/local/bin/perl
# change_ca.cgi
# Update the CA cert manually

require './webmin-lib.pl';
&ReadParseMime();
&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
&setup_ca() if (!$miniserv{'ca'});
&lock_file($miniserv{'ca'});
open(CA, ">$miniserv{'ca'}");
$in{'cert'} =~ s/\r//g;
$in{'cert'} =~ s/\n*$/\n/;
print CA $in{'cert'};
close(CA);
chmod(0700, $miniserv{'ca'});
&unlock_file($miniserv{'ca'});
unlink("$config_directory/acl/crl.pem");
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&redirect("");
sleep(1);
&restart_miniserv();
&webmin_log("changeca", undef, undef, \%in);

