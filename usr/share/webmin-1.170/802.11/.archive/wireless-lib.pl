#!/usr/bin/perl

my $st_configfile = 'wpa.conf';
my %st_config = ();
open CONFIG, $st_configfile or die ("Failed to open config file!");

while ($line = <CONFIG>) {
    if ((! ($line =~ /^\s*\#/)) &&
	$line =~ /\s*([^=\s]+)\s*=\s*([^\s]+)\s*\n/) {
	if ($1 ne '') { $st_config{$1} = $2; }
    }
}
close CONFIG;

sub st_write_iface {
    my %in = %{shift(@_)};
    my $file = st_get_conf('network_interface');
    my @conf_eth=('address','netmask','broadcast','up route add default gw');
    my $text = "auto eth1\niface eth1 inet static\n".
	"\taddress 192.168.168.168\n".
	"\tnetmask 255.255.255.0\n".
	"\tbroadcast 192.168.168.255\n\n".
	"auto lo\niface lo inet loopback\n\n#auto wlan0\n".
	"iface wlan0 inet static\n\taddress ";
    $text = $text.$in{'wlanaddress'}."\n\tnetmask 255.255.255.0\n";
    my $net = $in{'wlanaddress'};
    $net =~ s/\.\d+$/\.255/;
    $text = $text."\tbroadcast $net\n";
    $text = $text."\n\nauto eth0\niface eth0 inet static\n";
    foreach(@conf_eth) { $text = $text."\t".$_.' '.$in{$_}."\n"; }
    st_write2file($file,$text."\n");
}

#############
sub st_dns_stop {
    my %out = ('dyndns' => 0);
    st_write_config($st_configfile,\%out);
    foreach(2,3,4,5) {
	st_del("/etc/rc${_}.d/S20ddclient");
    }
    st_system("/etc/init.d/ddclient stop");
}

sub st_is_dns { 
    my %in = st_get_config($st_configfile);
    return $in{'dyndns'}; 
}

sub st_get_dns {
    my $file = st_get_conf('dyndns_conf');
    my $content = st_get_html($file);
    my $b = '[[:blank:]]*';
    my $i = '([^\s ]+)';
    if ($content =~ /login$b=$b$i\npassword$b=$b$i\n$i\n/) {
	return ($1,$2,$3);
    } else { 
	return ('','','');
    }
}

sub st_dns_start {
    my $login = shift;
    my $pass = shift;
    my $dom = shift;
    my %out = ('dyndns' => 1);
    st_write_config($st_configfile,\%out);
    st_mount();
    foreach(2,3,4,5) {
	st_system("cd /etc/rc${_}.d && ln -s ../init.d/ddclient S20ddclient");
    }
    st_umount();

    st_write2file(st_get_conf('dyndns_conf'),
		  "pid=/var/run/ddclient.pid\n".
		  "protocol=dyndns2\n".
		  "use=if, if=eth0\n".
		  "server=members.dyndns.org\n".
		  "login=$login\n".
		  "password=$pass\n".
		  "$dom\n");
    st_system("/etc/init.d/ddclient restart");
}
###########
sub st_dhcp_stop {
    my %out = ('dhcp' => 0);
    st_write_config($st_configfile,\%out);
    foreach(2,3,4,5) {
	st_del("/etc/rc${_}.d/S20dhcp");
    }
    st_system("/etc/init.d/dhcp stop");
}

sub st_is_dhcp { 
    my %in = st_get_config($st_configfile);
    return $in{'dhcp'}; 
}

sub st_get_dhcp {
    my $file = st_get_conf('dhcp_conf');
    my $content = st_get_html($file);

    if ($content =~ /range ([^ ]+) ([^ ]+)\;/) {
	return ($1,$2);
    } else { 
	return ('','');
    }
}

sub st_dhcp_start {
    my $subnet = shift;
    my $start = shift;
    my $end = shift;
    my $wlanip = shift;

    my %out = ('dhcp' => 1);
    st_write_config($st_configfile,\%out);
    st_mount();
    foreach(2,3,4,5) {
	st_system("cd /etc/rc${_}.d && ln -s ../init.d/dhcp S20dhcp");
    }
    st_umount();

    st_write2file(st_get_conf('dhcp_conf'),
		  "subnet $subnet netmask 255.255.255.0 {\n".
		  "option routers $wlanip; \n".
		  "option domain-name-servers 193.197.159.253; \n".
		  "range $start $end;\n}");
    
   st_system("/etc/init.d/dhcp restart");
}

sub st_get_config
{
    my $config	= shift;
    my %par	= ();
    open CONFIGFILE, "$config" or die ("Failed to open file $config");
    while ($line = <CONFIGFILE>) {
	if ((! ($line =~ /^\s*\#/)) &&
	    $line =~ /\s*([^=\s]+)\s*=\s*([^\s]+)\s*\n/) {
	    if ($1 ne '') { $par{$1} = $2; }
	}
    }
    close CONFIGFILE;
    return %par;
}

sub st_get_auth_ip {
    my %in = st_get_config(st_get_conf('secureap_conf'));
    return $in{'auth_server_ip'};
}


sub st_write_auth_ip {
    my $ip = shift;
    my $file = st_get_conf('secureap_conf');
    my %out = ('auth_server_ip' => $ip);
    st_write_config($file,\%out);
}

sub st_mount { 
#    return 1;
    st_system("mount -o remount,rw /"); 
}
sub st_umount {     
    #return 1;
    st_system("mount -o remount,ro /"); 
}


sub st_set_admin_pass {
    my $input = shift;
    st_mount();
    return st_system("perl ".st_get_conf('webmin_dir').
		     "/changepass.pl ".st_get_conf('webmin_etc_dir').
		     " admin $input");
    st_umount();
    
}

sub st_valid_mac {
    my $input = shift;
    if (($input =~ /^(([[:alnum:]]{2,2}:){5,5})[[:alnum:]]{2,2}$/)) {
	return 1;
    } else { return 0; }
}

sub st_add2file {
    my $file = shift;
    my $content = shift;
    st_mount();
    open CONFIG, ">>$file" or die "unable to open $file";
    print CONFIG $content; 
    close CONFIG;
    st_umount();
}

sub st_get_conf {
    my $item = shift;
    return $st_config{$item};
}

sub st_write2file {
    my $file = shift;
    my $content = shift;
    st_mount();
    open CONFIG, ">$file" or die "unable to open $file";
    print CONFIG $content; 
    close CONFIG;
    st_umount();
}

sub st_restart_dhcp {
    #return 1;
    return st_system("/etc/init.d/dhcp restart");
}

sub st_restart_network {
    #return 1;
    return st_system("/etc/init.d/networking restart");
}

sub st_restart_iface_eth0 {
    #return 1;
    return st_system("ifdown eth0; ifup eth0");
}

sub st_restart_iface_wlan0 {
    #return 1;
    return st_system("ifdown wlan0; ifup wlan0");
}


sub st_secmode_off {
    st_system("/etc/init.d/hostapd stop");
    st_system("/etc/init.d/pcmcia restart");
    st_system("/etc/init.d/dhcp restart");
}

sub st_secmode_on 
{
    st_system("/etc/init.d/pcmcia restart");
#     st_system("/etc/init.d/hostapd start");
    st_restart_hostapd();
    
    #st_system("killall hostapd");
    #st_system("hostapd $config_file");
}

sub st_reset() {
    #return 1;
    st_system("shutdown -r now");
}


sub st_shutdown {
 #   return 1;
    st_system("shutdown -h now");
}

sub st_stop_hostapd 
{
	st_system("/etc/init.d/hostapd stop");
	return;
}

sub st_restart_hostapd {
#    return 1;
    st_system("/etc/init.d/hostapd stop");
    st_system("/etc/init.d/hostapd start");

#old
    #st_system("killall hostapd");
    #st_system("hostapd $config_file");

}

sub st_iphost {
    my $input = shift;
    $orig = $input;
    $input =~ s/\d|\.//g;
    if ($input eq '') {
	$orig =~ s/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}//g;
	if ($orig eq '')  {
	    return 1;
	} else { 
	    return 0;
	}
    } else {
	return 1;
    }
}

sub st_ip {
    my $input = shift;
    if ($input =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
	return 1;
    } else {
	return 0;
    }
}

# sub st_ip {
#     my $input = shift;
#     if ($input eq '') { return 0; }
#     $orig = $input;
#     $input =~ s/\d|\.//g;
#     if ($input eq '') {
# 	$orig =~ s/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}//g;
# 	if ($orig eq '')  {
# 	    return 1;
# 	} else { 
# 	    return 0;
# 	}
#     } else {
# 	return 0;
#     }
# }

# sub st_number {
#     my $input = shift;
#     $input =~ s/\d//g;
#     if ($input eq '') { return 1; } else { return 0; } 
# }
sub st_number {
    my $input = shift;
    if ($input =~ /^\d+$/) { return 1; } else { return 0; } 
}

sub st_clean_rex {
    my $input = shift;
    $input =~ s/\*/\\\*/g;    
    $input =~ s/\./\\\./g;    
    $input =~ s/\?/\\\?/g;    
    $input =~ s/\{/\\\{/g;    
    $input =~ s/\}/\\\}/g;    
    $input =~ s/\^/\\\^/g;    
    $input =~ s/\$/\\\$/g;    
    return $input;
}

sub st_bad_char {
    my $input = shift;
    if ($input =~ /[^[:alnum:]-_\.äöüß@ ]/) {
	return 1;
    } else { return 0; }
}

sub st_del { 
    my $item = shift;
    st_mount();
    st_system("rm -r \"$item\""); 
    st_umount();
}

sub st_template_path { return "template.html"; }
sub st_html_path { return "html/"; }
sub st_webmin_dir { return st_get_conf{'webmin_dir'}; }
sub st_webmin_etcdir { return st_get_conf{'webmin_etc_dir'}; }
sub st_admin { return "admin"; }

sub st_system { 
    my $sys = shift;
    my $res = -1;
    $res = system($sys);
    if ($res == 0) { return 1; } else { return 0;}
}

sub st_isFile { 
    my $file = shift;
    my $res = 0;
    $res = system("test -f $file");
    if ($res == 0) { return 1; } else { return 0; }
}
sub st_isDir { 
    my $dir = shift;
    my $res = 0;
    $res = system("test -d $dir");
    if ($res == 0) { return 1; } else { return 0; }
}


sub st_get_html	# reads different HTML file and returns text/html
{
    my $htmlfile	= shift;
    my $htmlcontent	= "";
    open HTMLFILE, "$htmlfile" or die ("Failed to open file $htmlfile");
    
    while ($htmlline = <HTMLFILE>) {
	$htmlcontent = $htmlcontent.$htmlline;
    }
    
    close HTMLFILE;
    return $htmlcontent;
}

sub st_write_config {
    my $file = shift;
    my %in = %{shift(@_)};
    my $content = st_get_html($file);
    my $k,$v;
    foreach(keys %in) { 
	$k = $_;
	$v = $in{$k};
	$content =~ 
	    s/$k[[:blank:]]*=[[:blank:]]*[^\n]*\n/$k=$v\n/g;
    }
    st_mount();
    open CONFIG, ">$file" or die "unable to open $file";
    print CONFIG $content; 
    close CONFIG;
    st_umount();
}


sub st_index_page { return "template.html"; }
sub st_index_content { 
    my $content = st_get_html(st_index_page());
    $content =~ s/css\/styles\.css/\.\.\/css\/styles\.css/g;
    $content =~ s/href=cgi-bin\/(.*cgi)/href=$1/g;
    $content =~ s/img src=img\/logo3\.jpg/img src=\.\.\/img\/logo3\.jpg/g;
    my $expr = '<!--PRECONTENT-->(.|\s)*<!--POSTCONTENT-->';
    my $expr2 = '<!--CONTENT-->';
    $content =~ s/$expr/$expr2/g;
    return $content; 
}

sub st_output {
    my $index_content = st_index_content();
    my $file = shift;
    $content = st_get_html(st_html_path().$file);
    $index_content =~ s/\<\!\-\-CONTENT\-\-\>/$content/g;
    &header();
    print $index_content;
}

# print some content-file, after replaced values in Hash in Content
sub st_output2 {
    my $index_content = st_index_content();
    my $file = shift;
    my %in = %{shift(@_)};
    $content = st_get_html(st_html_path().$file);
    foreach(keys %in) {
	$content =~ s/\<\!\-\-$_\-\-\>/$in{$_}/g;
    }
    
    $index_content =~ s/\<\!\-\-CONTENT\-\-\>/$content/g;
    &header();
    print $index_content;
}

return 1;

