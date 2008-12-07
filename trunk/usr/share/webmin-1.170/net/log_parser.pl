# log_parser.pl
# Functions for parsing this module's logs

do 'net-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'host') {
	return &text("log_${action}_host", "<tt>$object</tt>");
	}
elsif ($action eq 'dns') {
	return $text{'log_dns'};
	}
elsif ($action eq 'routes') {
	return $text{'log_routes'};
	}
elsif ($type eq 'aifc' || $type eq 'bifc') {
	return &text("log_${action}_${type}", "<tt>$object</tt>",
		     $p->{'dhcp'} || $p->{'bootp'} ? $text{'log_dyn'} :
		     "<tt>$p->{'address'}</tt>");
	}
else {
	return undef;
	}
}

