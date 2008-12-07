#!/usr/bin/perl
# find.cgi
# Broadcast to other webmin servers

require './servers-lib.pl';
&ReadParse();
$access{'find'} || &error($text{'find_ecannot'});
use Socket;

foreach $s (&list_servers()) {
	$server{gethostbyname($s->{'host'})}++;
	}

# create the broadcast socket
$port = $config{'listen'} ? $config{'listen'} : 10000;
socket(BROAD, PF_INET, SOCK_DGRAM, getprotobyname("udp")) ||
	&error("socket failed : $!");
setsockopt(BROAD, SOL_SOCKET, SO_BROADCAST, pack("l", 1));

if (defined($in{'scan'})) {
	# send to all addresses on the given network
	$in{'scan'} =~ /^(\d+\.\d+\.\d+)\.0$/ || &error($text{'find_escan'});
	for($i=0; $i<256; $i++) {
		push(@broad, "$1.$i");
		}
	$limit = $config{'scan_time'};
	$myip = &get_my_address();
	if ($myip) {
		$myaddr{inet_aton($myip)}++;
		}
	}
else {
	# broadcast to some useful addresses
	$myip = &get_my_address();
	if ($myip) {
		push(@broad, &address_to_broadcast($myip, 0));
		$myaddr{inet_aton($myip)}++;
		}
	push(@broad, "255.255.255.255");
	$limit = 2;
	}

# Ignore our own IP addresses
if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	foreach $a (&foreign_call("net", "active_interfaces")) {
		push(@broad, $a->{'broadcast'})
			if ($a->{'broadcast'} && !defined($in{'scan'}));
		$myaddr{inet_aton($a->{'address'})}++
			if ($a->{'address'});
		}
	}

# send out the packets
@broad = &unique(@broad);
foreach $b (@broad) {
	send(BROAD, "webmin", 0, pack_sockaddr_in($port, inet_aton($b)));
	}

# Get and display responses
&ui_print_unbuffered_header(undef, $text{'find_title'}, "");
print "<p>\n";
if (defined($in{'scan'})) {
	print &text('find_scanning', "<tt>$in{'scan'}</tt>"),"<p>\n";
	}
else {
	print &text('find_broading', join(" , ", map { "<tt>$_</tt>" } @broad)),"<p>\n";
	}

$id = $tmstart = time();
while(time()-$tmstart < $limit) {
	local $rin;
	vec($rin, fileno(BROAD), 1) = 1;
	if (select($rin, undef, undef, 1)) {
		local $buf;
		local $from = recv(BROAD, $buf, 1024, 0);
		next if (!$from);
		local ($fromport, $fromaddr) = unpack_sockaddr_in($from);
		local $fromip = inet_ntoa($fromaddr);
		if ($fromip !~ /\.(255|0)$/ && !$already{$fromip}++) {
			local ($host, $port, $ssl) = split(/:/, $buf);
			if ($config{'resolve'}) {
				local $byname = gethostbyaddr($fromaddr,
							      AF_INET);
				$host = !$host && $byname ? $byname :
					!$host && !$byname ? $fromip :
							     $host;
				}
			else {
				$host = $fromip;
				}
			if ($host eq "0.0.0.0") {
				# Remote doesn't know it's IP or name
				local $byname = gethostbyaddr($fromaddr,
							      AF_INET);
				$host = $byname || $fromip;
				}
			local $url = ($ssl ? 'https' : 'http').
				     "://$host:$port/";
			if ($server{$fromaddr}) {
				print &text('find_already',
					    "<tt>$url</tt>"),"<br>\n";
				}
			elsif ($myaddr{$fromaddr}) {
				print &text('find_me',
					    "<tt>$url</tt>"),"<br>\n";
				}
			else {
				print &text('find_new',
					    "<tt>$url</tt>"),"<br>\n";
				local $serv = {	'id' => $id++,
						'ssl' => $ssl,
						'type' => 'unknown',
						'port' => $port,
						'host' => $host };
				&save_server($serv);
				&webmin_log("find", "server", $host, $serv);
				}
			$found++;
			}
		}
	}
print "$text{'find_none'}<p>\n" if (!$found);

&ui_print_footer("", $text{'index_return'});

