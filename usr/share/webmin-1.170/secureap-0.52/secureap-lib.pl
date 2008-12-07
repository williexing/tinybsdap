# secureap-lib.pl
# Functions for manipulating hostapd.conf

do '../web-lib.pl';

&init_config();
require '../ui-lib.pl';
use Config::Properties;

my $hostapd_config_file	= "/etc/madwifi.conf";
my $config_file		= "/etc/smartap.conf";

#	-- manipulates $hostapd_config_file
sub set_property
{
        my $pkey        = shift;
        my $pvalue      = shift;

        #       -- Open property file for reading
        open PROPS, "< $hostapd_config_file"
                or die "File read error in $hostapd_config_file: $!";

        #       -- Load properties
        my $properties  = new Config::Properties();
           $properties->load(*PROPS);

        close PROPS;

        #       -- Open property file for writing
        open PROPS, "> $hostapd_config_file"
                or die "unable to open configuration file for writing";

        $properties->changeProperty( $pkey, $pvalue);

        $properties->format( '%s=%s' );
        $properties->store(*PROPS);
        close PROPS;

        return;
}

#	-- manipulates $hostapd_config_file
sub get_property
{
        my $key = shift;

        open PROPS, "< $hostapd_config_file"
                or die "unable to open configuration file";

        my $properties = new Config::Properties();
           $properties->load(*PROPS);

        my $value = $properties->getProperty("$key");

        close PROPS;

        return $value;
}

#	-- manipulates /etc/smartap.conf
sub get_80211i_permenant
{
        open PROPS, "< $config_file"
                or die "unable to open $config_file";

        my $properties = new Config::Properties();
           $properties->load(*PROPS);

        my $value = $properties->getProperty("WPA2_ACTIVATE");

        close PROPS;
        return $value;
}

sub set_80211i_permenant
{
        my $pvalue      = shift;

        #       -- Open property file for reading
        open PROPS, "< $config_file"
                or die "File read error in $config_file: $!";

        #       -- Load properties
        my $properties  = new Config::Properties();
           $properties->load(*PROPS);

        close PROPS;

        #       -- Open property file for writing
        open PROPS, "> $config_file"
                or die "unable to open configuration file for writing";

	$properties->changeProperty("WPA2_ACTIVATE", $pvalue);

	$properties->format( '%s=%s' );
	$properties->store(*PROPS);
	close PROPS;

        return;
}

sub start_hostapd
{
	system("/etc/init.d/hostapd start");
}

sub stop_hostapd
{
	system("/etc/init.d/hostapd stop");
}
