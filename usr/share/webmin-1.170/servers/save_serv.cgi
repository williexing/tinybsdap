#!/usr/bin/perl
# save_serv.cgi
# Save or delete a server

require './servers-lib.pl';
&ReadParse();
$access{'edit'} || &error($text{'edit_ecannot'});
&error_setup($text{'save_err'});

if ($in{'id'}) {
	$serv = &get_server($in{'id'});
	&can_use_server($serv) || &error($text{'edit_ecannot'});
	}

if ($in{'delete'}) {
	# delete the server
	&delete_server($in{'id'});
	&webmin_log("delete", "server", $serv->{'host'}, $serv); 
	}
else {
	# validate inputs
	$in{'host'} =~ /^\S+$/ || &error($text{'save_ehost'});
	$in{'port'} =~ /^\d+$/ || &error($text{'save_eport'});
	if ($in{'mode'} == 1) {
		$in{'user'} =~ /\S/ || &error($text{'save_euser'});
		$in{'pass'} =~ /\S/ || &error($text{'save_epass'});
		}
	if ($in{'fast'} == 2 && $in{'mode'} == 1) {
		# Does the server have fastrpc.cgi ?
		local $con = &make_http_connection($in{'host'}, $in{'port'},
					   $in{'ssl'}, "GET", "/fastrpc.cgi");
		$in{'fast'} = 0;
		if (ref($con)) {
			&write_http_connection($con, "Host: $s->{'host'}\r\n");
			&write_http_connection($con, "User-agent: Webmin\r\n");
			$auth = &encode_base64("$in{'user'}:$in{'pass'}");
			$auth =~ s/\n//g;
			&write_http_connection($con,
					"Authorization: basic $auth\r\n");
			&write_http_connection($con, "\r\n");
			local $line = &read_http_connection($con);
			if ($line =~ /^HTTP\/1\..\s+401\s+/) {
				&error($text{'save_elogin'});
				}
			elsif ($line =~ /^HTTP\/1\..\s+200\s+/) {
				# It does .. tell the fastrpc.cgi process to die
				do {
					$line = &read_http_connection($con);
					$line =~ s/\r|\n//g;
					} while($line);
				$line = &read_http_connection($con);
				if ($line =~ /^1\s+(\S+)\s+(\S+)/) {
					local ($port = $1, $sid = $2, $error);
					&open_socket($in{'host'}, $port,
						     $sid, \$error);
					if (!$error) {
						close($sid);
						$in{'fast'} = 1;
						}
					}
				}
			&close_http_connection($con);
			}
		}
	elsif ($in{'fast'} == 2) {
		# No login provided, so we cannot say for now ..
		}

	# save the server
	@groups = split(/\0/, $in{'group'});
	push(@groups, $in{'newgroup'}) if ($in{'newgroup'});
	%serv = ( 'host' => $in{'host'},
		  'port' => $in{'port'},
		  'type' => $in{'type'},
		  'ssl' => $in{'ssl'},
		  'desc' => $in{'desc_def'} ? undef : $in{'desc'},
		  'group' => join("\t", @groups),
		  'fast' => $in{'fast'} );
	if ($in{'mode'} == 1) {
		$serv{'user'} = $in{'user'};
		$serv{'pass'} = $in{'pass'};
		}
	elsif ($in{'mode'} == 2) {
		$serv{'autouser'} = 1;
		}
	$serv{'id'} = $in{'new'} ? time() : $in{'id'};
	&save_server(\%serv);
	delete($serv{'pass'});
	&webmin_log($in{'new'} ? 'create' : 'modify', 'server',
		    $serv{'host'}, \%serv);
	}
&redirect("");

