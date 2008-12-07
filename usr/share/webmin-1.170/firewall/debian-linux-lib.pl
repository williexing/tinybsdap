# debians-linux-lib.pl
# Deal with debian's iptables save file and startup script

$has_debian_iptables = -r "/etc/init.d/iptables";
$debian_iptables_dir = "/var/lib/iptables";

if ($has_debian_iptables) {
	mkdir($debian_iptables_dir, 0755) if (!-d $debian_iptables_dir);
	$iptables_save_file = "$debian_iptables_dir/active";
	}

# apply_iptables()
# Applies the current iptables configuration from the save file
sub apply_iptables
{
if ($has_debian_iptables) {
	local $out = &backquote_logged("cd / ; /etc/init.d/iptables start 2>&1");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	return &iptables_restore();
	}
}

# unapply_iptables()
# Writes the current iptables configuration to the save file
sub unapply_iptables
{
if ($has_debian_iptables) {
	$out = &backquote_logged("cd / ; /etc/init.d/iptables save active 2>&1 </dev/null");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	return &iptables_save();
	}
}

# started_at_boot()
sub started_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_iptables) {
	return &init::action_status("iptables") == 2;
	}
else {
	return &init::action_status("webmin-iptables") == 2;
	}
}

sub enable_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_iptables) {
	&init::enable_at_boot("iptables");	 # Assumes init script exists
	}
else {
	&create_webmin_init();
	}
}

sub disable_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_iptables) {
	&init::disable_at_boot("iptables");
	}
else {
	&init::disable_at_boot("webmin-iptables");
	}
}

1;

