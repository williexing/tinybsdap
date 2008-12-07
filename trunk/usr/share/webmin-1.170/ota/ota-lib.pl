# ota-lib.pl
# Functions for setting up infrastructure
#

do '../web-lib.pl';
&init_config();
require '../ui-lib.pl';

use Config::Properties;

my $template_file       = "./template.html";
my $tbridge_html        = "./tbridge.html";
my $config_file         = "/etc/smartap.conf";

sub print_properties
{
        my $htmlcontent         = get_existing_properties();
        my $header_mac_ip       = get_header();
        my $peer_max            = get_peer_max();
        my $existing_peers      = get_existing_peers();

        open TEMPLATE, "$template_file"
                or die "unable to open $template_file";

        while (<TEMPLATE>)
        {
                s/\<\!\-\-SPECIAL_MESSAGE\-\-\>/$special_message/g;
                s/\<\!\-\-HEADER_MAC_IP\-\-\>/$header_mac_ip/g;
                s/\<\!\-\-CONTENT\-\-\>/$htmlcontent/;
                s/\<\!\-\-PEER_MAX\-\-\>/$peer_max/g;
                s/\<\!\-\-EXISTING_PEERS\-\-\>/$existing_peers/g;

                print;
        }

        close TEMPLATE;
        return;
}

sub get_existing_properties
{
        my $htmlcontent = get_html($tbridge_html);

        #       -- Open the config file to read config key-values

        open PROPS, "< $config_file"
                or die "unable to open configuration file";

        my $properties = new Config::Properties();
           $properties->load(*PROPS);

        #       -- Get all the properties modifiable from web-interface
        #        - could also use hash %props = $properties->properties()

        my $SELF_IP             = $properties->getProperty('SELF_IP');
        my $SELF_MAC            = get_self_mac();
        my $SELF_NETMASK        = $properties->getProperty('SELF_NETMASK');
        my $SELF_DEFAULT_GW     = $properties->getProperty('SELF_DEFAULT_GW');
        my $SELF_BROADCAST      = $properties->getProperty('SELF_BROADCAST');

        #       -- search and replace in the $htmlcontent string
        $htmlcontent    =~ s/<\!\-\-SELF_MAC\-\->/$SELF_MAC/g;
        $htmlcontent    =~ s/SELF_IP/value=$SELF_IP/g;
        $htmlcontent    =~ s/SELF_DEFAULT_GW/value=$SELF_DEFAULT_GW/g;
        $htmlcontent    =~ s/SELF_BROADCAST/value=$SELF_BROADCAST/g;
        $htmlcontent    =~ s/SELF_NETMASK/value=$SELF_NETMASK/g;

        close PROPS;
        return $htmlcontent;
}

sub get_existing_peers
{
        #       -- Open property file for reading
        open PROPS, "< $config_file"
                or die "File read error in $config_file: $!";

        #       -- Load properties
        my $props       = new Config::Properties();
           $props->load(*PROPS);

        my @pnames = $props->propertyNames();

        my $index       = 0;
        my $peershtml   = "";
        foreach $pname (@pnames)
        {
                if ($pname =~ 'PEERMAC_')
                {
                        @dummy  = split ('_', $pname);
                        $index  = $dummy[1];

                        $peermac        = $props->getProperty("PEERMAC_$index");
                        $peerip         = $props->getProperty("PEERIP_$index");

                        $peershtml = $peershtml."<tr><td valign=top>Node $index</td>
                                        <td>$peermac<br>$peerip<br>
                                        <form action=index.cgi method=post>
                                        <input type=submit name=action value=delete_peer>
                                        <input type=hidden name=peernodeindex value=$index>
                                        </form>
                                        </td></tr>";
                }
        }

        close PROPS;
        return $peershtml;
}
sub delete_peer
{
        $peernodeindex  = shift;

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

        $properties->deleteProperty("PEERMAC_$peernodeindex");
        $properties->deleteProperty("PEERIP_$peernodeindex");

        $properties->format( '%s=%s' );
        $properties->store(*PROPS);

        close PROPS;

}


sub get_html                                                            # reads different HTML file and returns text/html
{
        my $htmlfile    = shift;
        my $htmlcontent = "";

        open HTMLFILE, "$htmlfile" or die ("Failed to open file $htmlfile");

        while ($htmlline = <HTMLFILE>) {
                $htmlcontent = $htmlcontent.$htmlline;
        }

        close HTMLFILE;
        return $htmlcontent;
}
sub get_header                                                          # Returns the MAC addr & IP of the node for
{                                                                       #   displaying as header
        my $interface   = "br0";

        my $node_mac    = `/sbin/ifconfig $interface | grep "Link encap" | sed s/'.*HWaddr '//g | sed s/' '//g`;
        my $node_ip     = `/sbin/ifconfig $interface | grep "inet addr" | sed s/'.*inet addr:'//g | sed s/' .*'//g`;

        # my $node_ip   = `/sbin/ifconfig wlan0`;

        $header_html    = "$node_mac<br>$node_ip";

        # $header_html  = "Some stuff";

        return $header_html;
}

sub get_self_mac
{
        my $interface   = "br0";
        my $node_mac    = `/sbin/ifconfig $interface | grep "Link encap" | sed s/'.*HWaddr '//g | sed s/' '//g`;
        return $node_mac;
}

sub get_self_ip
{
        my $interface   = "br0";
        my $node_ip     = `/sbin/ifconfig $interface | grep "inet addr" | sed s/'.*inet addr:'//g | sed s/' .*'//g`;
        return $node_ip;
}

sub set_property
{
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

sub get_peer_max
{
        #       -- Open property file for reading
        open PROPS, "< $config_file"
                or die "File read error in $config_file: $!";

        #       -- Load properties
        my $props       = new Config::Properties();
           $props->load(*PROPS);

        my @pnames = $props->propertyNames();

        my $count       = 0;
        foreach $pname (@pnames)
        {
                if ($pname =~ 'PEERMAC_') {
                        $count ++;
                }
        }

        close PROPS;
        return $count;
}


return 1;
