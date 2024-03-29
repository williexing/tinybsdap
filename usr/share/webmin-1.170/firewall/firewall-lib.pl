# firewall-lib.pl
# Functions for parsing iptables-save format files
# - help pages

do '../web-lib.pl';
&init_config();
require '../ui-lib.pl';
if ($config{'save_file'}) {
	# Force use of a different save file, and webmin's functions
	$iptables_save_file = $config{'save_file'};
	}
else {
	if (-r "$module_root_directory/$gconfig{'os_type'}-lib.pl") {
		# Use the operating system's save file and functions
		do "$gconfig{'os_type'}-lib.pl";
		}

	if (!$iptables_save_file) {
		# Use webmin's own save file
		$iptables_save_file = "$module_config_directory/iptables.save";
		}
	}

%access = &get_module_acl();

@known_tables = ( "filter", "mangle", "nat" );
@known_args =   ('-p', '-m', '-s', '-d', '-i', '-o', '-f',
		 '--dport', '--sport', '--tcp-flags', '--tcp-option',
		 '--icmp-type', '--mac-source', '--limit', '--limit-burst',
		 '--ports', '--uid-owner', '--gid-owner',
		 '--pid-owner', '--sid-owner', '--state', '--tos', '-j',
		 '--to-ports', '--to-destination', '--to-source',
		 '--reject-with', '--dports', '--sports');

# get_iptables_save([file])
# Parse the iptables save file into a list of tables 
# format seems to be:
#  *table
#  :chain defaultpolicy
#  -A chain options
#  -N chain
#  COMMIT
sub get_iptables_save
{
local (@rv, $table, %got);
local $lnum = 0;
open(FILE, $_[0] || ($config{'direct'} ? "iptables-save |"
				       : $iptables_save_file));
local $cmt;
while(<FILE>) {
        local $read_comment;
	s/\r|\n//g;
	if (s/#\s*(.*)$//) {
		$cmt .= " " if ($cmt);
		$cmt .= $1;
		$read_comment=1;
		}
	if (/^\*(\S+)/) {
		# Start of a new table
		$got{$1}++;
		push(@rv, $table = { 'line' => $lnum,
				     'eline' => $lnum,
				     'name' => $1,
				     'rules' => [ ],
				     'defaults' => { } });
		}
	elsif (/^:(\S+)\s+(\S+)/) {
		# Default policy definition
		$table->{'defaults'}->{$1} = $2;
		}
	elsif (/^(\[[^\]]*\]\s+)?-N\s+(\S+)(.*)/) {
		# New chain definition
		$table->{'defaults'}->{$2} = '-';
		}
	elsif (/^(\[[^\]]*\]\s+)?-A\s+(\S+)(.*)/) {
		# Rule definition
		local $rule = { 'line' => $lnum,
				'eline' => $lnum,
				'index' => scalar(@{$table->{'rules'}}),
				'cmt' => $cmt,
				'chain' => $2,
				'args' => $3 };
		push(@{$table->{'rules'}}, $rule);

		# Parse arguments
		foreach $a (@known_args) {
			local @vl;
			while($rule->{'args'} =~ s/\s+(!?)\s*($a)\s+(!?)\s*(([^ \-!]\S*(\s+|$))+)/ / || $rule->{'args'} =~ s/\s+(!?)\s*($a)()(\s+|$)/ /) {
				push(@vl, [ $1 || $3, split(/\s+/, $4) ]);
				}
			local ($aa = $a); $aa =~ s/^-+//;
			if ($a eq '-m') {
				$rule->{$aa} = \@vl if (@vl);
				}
			else {
				$rule->{$aa} = $vl[0];
				}
			}
		}
	elsif (/^COMMIT/) {
		# Marks end of a table
		$table->{'eline'} = $lnum;
		}
	elsif (/\S/) {
		&error(&text('eiptables', "<tt>$_</tt>"));
		}
	$lnum++;
	if (! defined($read_comment)) { $cmt=undef; }
	}
close(FILE);
@rv = sort { $a->{'name'} cmp $b->{'name'} } @rv;
local $i;
map { $_->{'index'} = $i++ } @rv;
return @rv;
}

# save_table(&table)
# Updates an existing IPtable in the save file
sub save_table
{
local $lref;
if ($config{'direct'}) {
	# Read in the current iptables-save output
	$lref = &read_file_lines("iptables-save |");
	}
else {
	# Updating the save file
	$lref = &read_file_lines($iptables_save_file);
	}
local @lines = ( "*$_[0]->{'name'}" );
local ($d, $r);
foreach $d (keys %{$_[0]->{'defaults'}}) {
	push(@lines, ":$d $_[0]->{'defaults'}->{$d} [0:0]");
	}
foreach $r (@{$_[0]->{'rules'}}) {
	local $line;
	$line = "# $r->{'cmt'}\n" if ($r->{'cmt'});
	$line .= "-A $r->{'chain'}";
	foreach $a (@known_args) {
		local ($aa = $a); $aa =~ s/^-+//;
		if ($r->{$aa}) {
			local @al = ref($r->{$aa}->[0]) ?
					@{$r->{$aa}} : ( $r->{$aa} );
			foreach $ag (@al) {
				local $n = shift(@$ag);
				$line .= " ".join(" ", $n ? ( $n ) : (),
						       $a, @$ag);
				}
			}
		}
	$line .= " $r->{'args'}" if ($r->{'args'} =~ /\S/);
	push(@lines, $line);
	}
push(@lines, "COMMIT");
if (defined($_[0]->{'line'})) {
	# Update in file
	splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
	       @lines);
	}
else {
	# Append new table to file
	push(@$lref, "# Generated by webmin", @lines, "# Completed");
	}
if ($config{'direct'}) {
	# Pass new lines to iptables-restore
	open(SAVE, "| iptables-restore");
	print SAVE map { $_."\n" } @$lref;
	close(SAVE);
	}
else {
	# Just save the file
	&flush_file_lines();
	}
}

# describe_rule(&rule)
sub describe_rule
{
local (@c, $d);
foreach $d ('p', 's', 'd', 'i', 'o', 'f', 'dport',
	    'sport', 'tcp-flags', 'tcp-option',
	    'icmp-type', 'mac-source', 'limit', 'limit-burst',
	    'ports', 'uid-owner', 'gid-owner',
	    'pid-owner', 'sid-owner', 'state', 'tos',
	    'dports', 'sports') {
	if ($_[0]->{$d}) {
		local ($n, @v) = @{$_[0]->{$d}};
		@v = map { uc($_) } @v if ($d eq 'p');
		local $txt = &text("desc_$d$n", map { "<b>$_</b>" } @v);
		push(@c, $txt) if ($txt);
		}
	}
local $rv;
if (@c) {
	$rv = &text('desc_conds', join(" $text{'desc_and'} ", @c));
	}
else {
	$rv = $text{'desc_always'};
	}
return $rv;
}

# create_firewall_init()
# Do whatever is needed to have the firewall started at boot time
sub create_firewall_init
{
if (defined(&enable_at_boot)) {
	# Use distro's function
	&enable_at_boot();
	}
else {
	# May need to create init script
	&create_webmin_init();
	}
}

# create_webmin_init()
# Create (if necessary) the Webmin iptables init script
sub create_webmin_init
{
local $res = &has_command("iptables-restore");
local $ipt = &has_command("iptables");
local $start = "$res <$iptables_save_file";
local $stop = "$ipt -t filter -F\n".
	      "$ipt -t nat -F\n".
	      "$ipt -t mangle -F\n".
	      "$ipt -t filter -P INPUT ACCEPT\n".
	      "$ipt -t filter -P OUTPUT ACCEPT\n".
	      "$ipt -t filter -P FORWARD ACCEPT\n".
	      "$ipt -t nat -P PREROUTING ACCEPT\n".
	      "$ipt -t nat -P POSTROUTING ACCEPT\n".
	      "$ipt -t nat -P OUTPUT ACCEPT\n".
	      "$ipt -t mangle -P PREROUTING ACCEPT\n".
	      "$ipt -t mangle -P OUTPUT ACCEPT";
&foreign_require("init", "init-lib.pl");
&init::enable_at_boot("webmin-iptables", "Load IPtables save file",
		      $start, $stop);
}

# interface_choice(name, value)
sub interface_choice
{
local @ifaces;
if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	local $i;
	foreach $i (&net::active_interfaces(), &net::boot_interfaces()) {
		push(@ifaces, $i->{'fullname'});
		}
	@ifaces = &unique(@ifaces);
	}
if (@ifaces) {
	local $rv = "<select name=$_[0]>\n";
	local ($i, $found);
	foreach $i (@ifaces) {
		$rv .= sprintf "<option value=%s %s>%s\n",
			$i, $_[1] eq $i ? "selected" : "", $i;
		$found++ if ($_[1] eq $i);
		}
	#$rv .= "<option value=$_[1] selected>$_[1]\n" if (!$found && $_[1]);
	$rv .= sprintf "<option value='' %s> %s\n",
			!$found && $_[1] ? "selected" : "", $text{'edit_oifc'};
	$rv .= "</select>\n";
	$rv .= sprintf "<input name=$_[0]_other size=6 value='%s'>\n",
			!$found ? $_[1] : "";
	return $rv;
	}
else {
	return "<input name=$_[0] size=6 value='$_[1]'>";
	}
}

sub check_previous
{
	my (@p,$max,$n)=@_;
	for ($i=0;$i<$max;$i++)
	{
		if ($n eq $p[$i]){return 1}
	}
	return -1;
}
 
sub by_string_for_iptables
{
	my @p=("PREROUTING","INPUT","FORWARD","OUTPUT","POSTROUTING");

	for ($i=0;$i<@p;$i++)
	{
		if ($a eq $p[$i]){
			if (&check_previous(@p,$i,$b)){return -1;}
			else{ return 1;}}
		if ($b eq $p[$i]){
			if (&check_previous(@p,$i,$b)){return 1;}
			else{ return -1;}}
	}

	return $a cmp $b;
}

sub missing_firewall_commands
{
local $c;
foreach $c ("iptables", "iptables-restore", "iptables-save") {
	return $c if (!&has_command($c));
	}
return undef;
}

# iptables_restore()
# Activates the current firewall rules, and returns any error
sub iptables_restore
{
local $out = &backquote_logged("cd / ; iptables-restore <$iptables_save_file 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

# iptables_save()
# Saves the active firewall rules, and returns any error
sub iptables_save
{
local $out = &backquote_logged("iptables-save >$iptables_save_file 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

# can_edit_table(name)
sub can_edit_table
{
return $access{$_[0]};
}

# run_before_command()
# Runs the before-saving command, if any
sub run_before_command
{
if ($config{'before_cmd'}) {
	&system_logged("($config{'before_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# run_after_command()
# Runs the after-saving command, if any
sub run_after_command
{
if ($config{'after_cmd'}) {
	&system_logged("($config{'after_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# run_before_apply_command()
# Runs the before-applying command, if any. If it failes, returns the error
# message output
sub run_before_apply_command
{
if ($config{'before_apply_cmd'}) {
	local $out = &backquote_logged("($config{'before_apply_cmd'}) </dev/null 2>&1");
	return $out if ($?);
	}
return undef;
}

# run_after_apply_command()
# Runs the after-applying command, if any
sub run_after_apply_command
{
if ($config{'after_apply_cmd'}) {
	&system_logged("($config{'after_apply_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# apply_configuration()
# Calls all the appropriate apply functions and programs, and returns an error
# message if anything fails
sub apply_configuration
{
local $err = &run_before_apply_command();
return $err if ($err);
if (defined(&apply_iptables)) {
	# Call distro's apply command
	$err = &apply_iptables();
	}
else {
	# Manually run iptables-restore
	$err = &iptables_restore();
	}
return $err if ($err);
&run_after_apply_command();
return undef;
}

# list_cluster_servers()
# Returns a list of servers on which the firewall is managed
sub list_cluster_servers
{
&foreign_require("servers", "servers-lib.pl");
local %ids = map { $_, 1 } split(/\s+/, $config{'servers'});
return grep { $ids{$_->{'id'}} } &servers::list_servers();
}

# add_cluster_server(&server)
sub add_cluster_server
{
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", @sids, $_[0]->{'id'});
&save_module_config();
}

# delete_cluster_server(&server)
sub delete_cluster_server
{
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", grep { $_ != $_[0]->{'id'} } @sids);
&save_module_config();
}

# server_name(&server)
sub server_name
{
return $_[0]->{'desc'} ? $_[0]->{'desc'} : $_[0]->{'host'};
}

# copy_to_cluster([force])
# Copy all firewall rules from this server to those in the cluster
sub copy_to_cluster
{
return if (!$config{'servers'});		# no servers defined
return if (!$_[0] && $config{'cluster_mode'});	# only push out when applying
local $s;
local $ltemp;
if ($config{'direct'}) {
	# Dump current configuration
	$ltemp = &tempname();
	system("iptables-save >$ltemp 2>/dev/null");
	}
foreach $s (&list_cluster_servers()) {
	&remote_foreign_require($s->{'host'}, "firewall", "firewall-lib.pl");
	if ($config{'direct'}) {
		# Directly activate on remote server!
		local $rtemp = &remote_write($s->{'host'}, $ltemp);
		unlink($ltemp);
		local $err = &remote_eval($s->{'host'}, "firewall",
		  "\$out = `iptables-restore <$rtemp 2>&1`; [ \$out, \$? ]"); 
		&remote_eval($s->{'host'}, "firewall", "unlink('$rtemp')");
		&error(&text('apply_remote', $s->{'host'}, $err->[0]))
			if ($err->[1]);
		}
	else {
		# Can just copy across save file
		local $rfile = &remote_eval($s->{'host'}, "firewall",
					    "\$iptables_save_file");
		&remote_write($s->{'host'}, $iptables_save_file, $rfile);
		}
	}
}

# apply_cluster_configuration()
# Activate the current configuration on all servers in the cluster
sub apply_cluster_configuration
{
return undef if (!$config{'servers'});
if ($config{'cluster_mode'}) {
	&copy_to_cluster(1);
	}
local $s;
foreach $s (&list_cluster_servers()) {
	&remote_foreign_require($s->{'host'}, "firewall", "firewall-lib.pl");
	local $err = &remote_foreign_call($s->{'host'}, "firewall", "apply_configuration");
	if ($err) {
		return &text('apply_remote', $s->{'host'}, $err);
		}
	}
return undef;
}

1;

