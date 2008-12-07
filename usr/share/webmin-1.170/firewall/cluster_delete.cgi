#!/usr/bin/perl
# Remove some servers from the managed list

require './firewall-lib.pl';
&ReadParse();
&foreign_require("servers", "servers-lib.pl");
@servers = &list_cluster_servers();

foreach $id (split(/\0/, $in{'d'})) {
	($server) = grep { $_->{'id'} == $id } @servers;
	&delete_cluster_server($server);
	}
&redirect("cluster.cgi");

