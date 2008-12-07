use Config::Properties;

my $config_file         = "/etc/smartap.conf";
my $hostapd_config_file	= "/etc/madwifi.conf";

#	-- Functions to manipulate the smartap.conf file
sub set_property
{
        mountrw();
        my $pkey        = shift;
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

        $properties->changeProperty( $pkey, $pvalue);

        $properties->format( '%s=%s' );
        $properties->store(*PROPS);
        close PROPS;

        return;
}

sub get_property
{
        my $key = shift;

        open PROPS, "< $config_file"
                or die "unable to open configuration file";

        my $properties = new Config::Properties();
           $properties->load(*PROPS);

        my $value = $properties->getProperty("$key");

        close PROPS;

        return $value;
}

#	-- Functions to manipulate hostapd.conf file
sub set_hostapd_property
{
        my $pkey        = shift;
        my $pvalue      = shift;
	mountrw();
        #       -- Open property file for reading
        open PROPS, "< $hostapd_config_file"
                or die "File read error in $hostapd_conf_file: $!";

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

sub get_hostapd_property
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

sub getConfig
{
	my 	$config_file	= shift;
		$config_file	= "/etc/" . $config_file;

	#	-- Use a hash to load all smartap.conf vars at once
#	my $config_file	= "/etc/smartap.conf";
	open (CONFIG, "<$config_file") || die ("File I/O Error: $!");
	my %config_hash	= ();
	while (<CONFIG>)
	{
		my @nv_pair	= split("\=", $_);
		%config_hash->{$nv_pair[0]} = $nv_pair[1];
	}
	
	return %config_hash;
}
