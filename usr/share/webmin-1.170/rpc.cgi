#!/usr/bin/perl
# rpc.cgi
# Handles remote_foreign_require and remote_foreign_call requests from
# other webmin servers. State is preserved by starting a process for each
# session that listens for requests on a named pipe (and dies after a few
# seconds of inactivity)
# access{'rpc'}  0=not allowed 1=allowed 2=allowed if root or admin

do './web-lib.pl';
use POSIX;
&init_config();
if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	local $got;
	while(length($rawarg) < $ENV{'CONTENT_LENGTH'}) {
		read(STDIN, $got, $ENV{'CONTENT_LENGTH'}) > 0 || last;
		$rawarg .= $got;
		}
	}
else {
	$rawarg = $ENV{'QUERY_STRING'};
	}
$arg = &unserialise_variable($rawarg);
$| = 1;
print "Content-type: text/plain\n\n";

# Can this user make remote calls?
%access = &get_module_acl();
if ($access{'rpc'} == 0 || $access{'rpc'} == 2 &&
    $base_remote_user ne 'admin' && $base_remote_user ne 'root') {
	print &serialise_variable( { 'status' => 0 } );
	exit;
	}

if ($arg->{'newsession'}) {
	# Need to fork a new session-handler process
	$fifo1 = &tempname();
	$fifo2 = &tempname();
	mkfifo($fifo1, 0700);
	mkfifo($fifo2, 0700);
	if (!fork()) {
		# This is the subprocess where execution really happens
		$SIG{'ALRM'} = "fifo_timeout";
		untie(*STDIN);
		untie(*STDOUT);
		close(STDIN);
		close(STDOUT);
		close(miniserv::SOCK);
		local $stime = time();
		while(1) {
			local ($rawcmd, $cmd, @rv);
			alarm(10);
			open(FIFO, $fifo1) || last;
			while(<FIFO>) {
				$rawcmd .= $_;
				}
			close(FIFO);
			alarm(0);
			$cmd = &unserialise_variable($rawcmd);
			if ($cmd->{'action'} eq 'quit') {
				# time to end this session (after the reply)
				@rv = ( { 'time' => time() - $stime } );
				}
			elsif ($cmd->{'action'} eq 'require') {
				# require a library
				&foreign_require($cmd->{'module'},
						 $cmd->{'file'});
				@rv = ( { 'session' => [ $fifo1, $fifo2 ] } );
				}
			elsif ($cmd->{'action'} eq 'call') {
				# execute a function
				@rv = &foreign_call($cmd->{'module'},
						    $cmd->{'func'},
						    @{$cmd->{'args'}});
				}
			elsif ($cmd->{'action'} eq 'eval') {
				# eval some perl code
				if ($cmd->{'module'}) {
					@rv = eval <<EOF;
package $cmd->{'module'};
$cmd->{'code'}
EOF
					}
				else {
					@rv = eval $cmd->{'code'};
					}
				}
			open(FIFO, ">$fifo2");
			if (@rv == 1) {
				print FIFO &serialise_variable(
					{ 'status' => 1, 'rv' => $rv[0] } );
				}
			else {
				print FIFO &serialise_variable(
					{ 'status' => 1, 'arv' => \@rv } );
				}
			close(FIFO);
			last if ($cmd->{'action'} eq 'quit');
			}
		unlink($fifo1);
		unlink($fifo2);
		exit;
		}
	$session = [ $fifo1, $fifo2 ];
	}
else {
	# Use the provided session id
	$session = $arg->{'session'};
	}

if ($arg->{'action'} eq 'ping') {
	# Just respond with an OK
	print &serialise_variable( { 'status' => 1 } );
	}
elsif ($arg->{'action'} eq 'check') {
	# Check if some module is supported
	print &serialise_variable(
		{ 'status' => 1,
		  'rv' => &foreign_check($arg->{'module'}) } );
	}
elsif ($arg->{'action'} eq 'config') {
	# Get the config for some module
	local %config = &foreign_config($arg->{'module'});
	print &serialise_variable(
		{ 'status' => 1, 'rv' => \%config } );
	}
elsif ($arg->{'action'} eq 'write') {
	# Transfer data to a local temp file
	local $file = $arg->{'file'} ? $arg->{'file'} : &tempname();
	open(FILE, ">$file");
	print FILE $arg->{'data'};
	close(FILE);
	print &serialise_variable(
		{ 'status' => 1, 'rv' => $file } );
	}
elsif ($arg->{'action'} eq 'read') {
	# Transfer data from a file
	local ($data, $got);
	open(FILE, $arg->{'file'});
	while(read(FILE, $got, 1024) > 0) {
		$data .= $got;
		}
	close(FILE);
	print &serialise_variable(
		{ 'status' => 1, 'rv' => $data } );
	}
else {
	# Pass the request on to the subprocess
	open(FIFO, ">$session->[0]");
	print FIFO $rawarg;
	close(FIFO);
	open(FIFO, $session->[1]);
	while(<FIFO>) {
		print;
		}
	close(FIFO);
	}

sub fifo_timeout
{
unlink($fifo1);
unlink($fifo2);
exit;
}

