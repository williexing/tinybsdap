#!/usr/bin/perl
# index.cgi

require './ota-lib.pl';

mountrw();

&ReadParse();
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
        &help_search_link("iptables", "man", "doc"));

my $action      = $in{action};

# print "action = $action"; return;

if ($action eq "set_self_node")
{
        set_property("SELF_IP", $in{selfip});
        set_property("SELF_NETMASK", $in{selfnetmask});
        set_property("SELF_BROADCAST", $in{selfbroadcast});
        set_property("SELF_DEFAULT_GW", $in{selfdefaultgw});
}
elsif ($action eq "set_peer")
{
        $peer_max       = get_peer_max();

        if ($in{newpeermac} ne "")
        {
                set_property("PEERMAC_$peer_max", $in{newpeermac});
                set_property("PEERIP_$peer_max", $in{newpeerip});
        }
}
elsif ($action eq "delete_peer")
{
        delete_peer($in{peernodeindex});
}

print_properties();


&ui_print_footer("/", $text{'index'});
