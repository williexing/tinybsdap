# net-simple-lib.pl
# Functions for setting up network 
# -- 	mainly holds place to maintain webmin structures

do '../web-lib.pl';

# 	-- Property file manipulation
do '../web-lib-props.pl';		

&init_config();
require '../ui-lib.pl';

sub get_prim_dns
{
	my $key = shift;

	open PROPS, "< /etc/resolv.conf"
		or die "unable to open /etc/resolv.conf file";

	@prim_dns = split(" ", <PROPS>);
	close PROPS;
	return $prim_dns[1];
}

sub get_dns_servers
{
	open PROPS, "< /etc/resolv.conf" || die "unable to open /etc/resolv.conf file";

	my @dns_servers	= ();
	while (<PROPS>)
	{
		my @tmp	=	split(" ", $_);
		push @dns_servers, $tmp[1] if ($tmp[1] ne '');
	}
	close PROPS;
	return @dns_servers;
}
1;