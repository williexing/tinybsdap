#!/usr/bin/perl

do '../web-lib.pl';
do '../web-lib-props.pl';

&init_config();

my $IWCONFIG 	= "/sbin/iwconfig";
my $IWPRIV		= "/sbin/iwpriv";
my $PRISM2_PARAM= "/sbin/prism2_param";
my $conf_file	= "/etc/smartap.conf";

my $WLAN_DEV = "ath0";
my $DEFAULT_WIRELESS_INTERFACE	= "ath0";

sub st_get_param
{
	my $param	= shift;
	my %par_values	= st_get_config();

	return $par_values{$param};
}

sub st_set_bcast_ssid
{
	my $bcast_ssid	= shift;
	system ("$PRISM2_PARAM $WLAN_DEV enh_sec $bcast_ssid");
}

sub st_get_iwconfig
{
	# someone surely has a better idea to do this..
	return `/sbin/iwconfig $WLAN_DEV | sed -e s/'wlan0'//g | sed -e s/'     '//g`;
}

sub st_get_ifconfig
{
	# someone surely has a better idea to do this..
	return `/sbin/ifconfig $DEFAULT_WIRELESS_INTERFACE | sed -e s/$DEFAULT_WIRELESS_INTERFACE\:\//g | sed -e s/^\s*//g`;
}

sub st_run_iwconfig
{
	#	-- Defaults
	my $essid 	= "smartap";
	my $txpower	= "100mW";
	my $channel	= "3";
	my $wepkey	= "";
	my $mode	= "master";

	#	-- Read parameters from config file (/etc/smartap.conf)
	my %config_pars = st_get_config($conf_file);

	$essid		= $config_pars{wlan0_essid};
	$txpower	= $config_pars{wlan0_txpower};
	$channel	= $config_pars{wlan0_channel};
	$wepkey		= $config_pars{wlan0_wepkey};
	$mode		= $config_pars{wlan0_mode};

	#	-- Run the iwconfig command
	if ($wepkey ne "")
	{
		# print "$IWCONFIG $WLAN_DEV essid $essid txpower $txpower channel $channel enc $wepkey"; exit;
		system("$IWCONFIG $WLAN_DEV mode $mode essid $essid channel $channel enc $wepkey bitrate 11mbps txpower $txpower");
	}
	else
	{
		# print "$IWCONFIG $WLAN_DEV essid $essid txpower $txpower channel $channel enc off"; exit;
		system("$IWCONFIG $WLAN_DEV mode $mode essid $essid channel $channel enc off bitrate 11mbps txpower $txpower");
	}
}

sub st_get_config
{
    my %par     = ();

    open CONFIGFILE, "$conf_file" or die ("Failed to open file $config");
    while ($line = <CONFIGFILE>) {
        if ((! ($line =~ /^\s*\#/)) &&
            $line =~ /\s*([^=\s]+)\s*=\s*([^\s]+)\s*\n/) {
            if ($1 ne '') { $par{$1} = $2; }
        }
    }
    close CONFIGFILE;
    return %par;
}

sub set_property
{
	my $pkey        = shift;
	my $pvalue      = shift;

        #       -- Open property file for reading
        open PROPS, "< $conf_file"
                or die "File read error in $config_file: $!";

        #       -- Load properties
        my $properties  = new Config::Properties();
           $properties->load(*PROPS);

        close PROPS;

        #       -- Open property file for writing
        open PROPS, "> $conf_file"
                or die "unable to open config file $conf_file for write";

        $properties->changeProperty( $pkey, $pvalue);

        $properties->format( '%s=%s' );
        $properties->store(*PROPS);

        close PROPS;
}


# 	-- Reads any text file and returns text
sub st_read_file 
{
    my $htmlfile        = shift;
    my $htmlcontent     = "";
    open HTMLFILE, "$htmlfile" or die ("Failed to open file $htmlfile");

    while ($htmlline = <HTMLFILE>) {
        $htmlcontent = $htmlcontent.$htmlline;
    }

    close HTMLFILE;
    return $htmlcontent;
}

#	-- Deprecated. To retreive SSID
sub st_get_ssid
{
	my $ssid	= `$IWCONFIG $WLAN_DEV | \
				grep ESSID | \
				sed -e s/'wlan0'//g | \
				sed -e s/'ESSID'//g | \
				sed -e s/'IEEE 802.11b'//g | \
				sed -e s/\://g | sed -e s/'"'//g`;

	# Brute force. Try if awk can be employed
	return $ssid;
}
