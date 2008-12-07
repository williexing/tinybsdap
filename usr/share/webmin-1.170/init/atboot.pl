#!/usr/bin/perl
# atboot.pl
# Called by setup.sh to have webmin started at boot time

$no_acl_check++;
require './init-lib.pl';
$product = $ARGV[0] || "webmin";
$ucproduct = ucfirst($product);

if ($config{'darwin_setup'}) {
	# Darwin System
	open(LOCAL, ">>$config{'hostconfig'}");
	print LOCAL "WEBMIN=-YES-\n";
	close(LOCAL);
	
	$paramlist = "$config{'darwin_setup'}/$ucproduct/$config{'plist'}";
	$scriptfile = "$config{'darwin_setup'}/$ucproduct/$ucproduct";
	
	# On a Virgin darwin system, $config{'darwin_setup'} may not yet exist
	-d "$config{'darwin_setup'}/$ucproduct" || do {
		if ( -d "$config{'darwin_setup'}" ) {
			mkdir ("$config{'darwin_setup'}/$ucproduct", 0755);
			} else {
			mkdir ("$config{'darwin_setup'}", 0755);
			mkdir ("$config{'darwin_setup'}/$ucproduct",0755);
			}
		} until -d "$config{'darwin_setup'}/$ucproduct";

	open(PLIST, ">$paramlist");
	print PLIST "{\n";
	print PLIST "\t\tDescription\t\t= \"$ucproduct system administration daemon\";\n";
	print PLIST "\t\tProvides\t\t= (\"$ucproduct\");\n";
	print PLIST "\t\tRequires\t\t= (\"Resolver\");\n";
	print PLIST "\t\tOrderPreference\t\t= \"None\";\n";
	print PLIST "\t\tMessages =\n";
	print PLIST "\t\t{\n";
	print PLIST "\t\t\tstart\t= \"Starting $ucproduct Server\";\n";
	print PLIST "\t\t\tstop\t= \"Stopping $ucproduct Server\";\n";
	print PLIST "\t\t};\n";
	print PLIST "}\n";
	close(PLIST);
	# Create Bootup Script
	open(STARTUP, ">$scriptfile");
	print STARTUP "#!/bin/sh\n\n";
	print STARTUP ". /etc/rc.common\n\n";
	print STARTUP "if [ \"\${WEBMIN:=-NO-}\" = \"-YES-\" ]; then\n";
	print STARTUP "\tConsoleMessage \"Starting $ucproduct\"\n";
	print STARTUP "\t$config_directory/start >/dev/null 2>&1 </dev/null\n";
	print STARTUP "fi\n";
	close(STARTUP);
	chmod(0750, $scriptfile);
	}
elsif (!$config{'init_base'}) {
	# Add to the boot time rc script
	$lref = &read_file_lines($config{'local_script'});
	for($i=0; $i<@$lref && $lref->[$i] !~ /^exit\s/; $i++) { }
	splice(@$lref, $i, 0, "$config_directory/start >/dev/null 2>&1 </dev/null # Start $ucproduct");
	&flush_file_lines();
	print STDERR "Added to bootup script $config{'local_script'}\n";
	}
else {
	# Create a bootup action
	@start = &get_start_runlevels();
	$fn = &action_filename($product);
	open(ACTION,">$fn");
	$desc = "Start/stop $ucproduct";
	print ACTION "#!/bin/sh\n";
	$start_order = "9" x $config{'order_digits'};
	$stop_order = "9" x $config{'order_digits'};
	if ($config{'chkconfig'}) {
		# Redhat-style description: and chkconfig: lines
		print ACTION "# description: $desc\n";
		print ACTION "# chkconfig: $config{'chkconfig'} ",
			     "$start_order $stop_order\n";
		}
	elsif ($config{'init_info'}) {
		# Suse-style init info section
		print ACTION "### BEGIN INIT INFO\n",
			     "# Provides: $product\n",
			     "# Required-Start: \$network \$syslog\n",
			     "# Required-Stop: \$network\n",
			     "# Default-Start: ",join(" ", @start),"\n",
			     "# Description: $desc\n",
			     "### END INIT INFO\n";
		}
	else {
		# Just description in a comment
		print ACTION "# $desc\n";
		}
	print ACTION "\n";
	print ACTION "case \"\$1\" in\n";

	print ACTION "'start')\n";
	print ACTION "\t$config_directory/start >/dev/null 2>&1 </dev/null\n";
	print ACTION "\tRETVAL=\$?\n";
	if ($config{'subsys'}) {
		print ACTION "\tif [ \"\$RETVAL\" = \"0\" ]; then\n";
		print ACTION "\t\ttouch $config{'subsys'}/$product\n";
		print ACTION "\tfi\n";
		}
	print ACTION "\t;;\n";

	print ACTION "'stop')\n";
	print ACTION "\t$config_directory/stop\n";
	print ACTION "\tRETVAL=\$?\n";
	if ($config{'subsys'}) {
		print ACTION "\tif [ \"\$RETVAL\" = \"0\" ]; then\n";
		print ACTION "\t\trm -f $config{'subsys'}/$product\n";
		print ACTION "\tfi\n";
		}
	print ACTION "\t;;\n";

	print ACTION "'status')\n";
	print ACTION "\tpidfile=`grep \"^pidfile=\" $config_directory/miniserv.conf | sed -e 's/pidfile=//g'`\n";
	print ACTION "\tif [ -s \$pidfile ]; then\n";
	print ACTION "\t\tpid=`cat \$pidfile`\n";
	print ACTION "\t\tkill -0 \$pid >/dev/null 2>&1\n";
	print ACTION "\t\tif [ \"\$?\" = \"0\" ]; then\n";
	print ACTION "\t\t\techo \"$product (pid \$pid) is running\"\n";
	print ACTION "\t\t\tRETVAL=0\n";
	print ACTION "\t\telse\n";
	print ACTION "\t\t\techo \"$product is stopped\"\n";
	print ACTION "\t\t\tRETVAL=1\n";
	print ACTION "\t\tfi\n";
	print ACTION "\telse\n";
	print ACTION "\t\techo \"$product is stopped\"\n";
	print ACTION "\t\tRETVAL=1\n";
	print ACTION "\tfi\n";
	print ACTION "\t;;\n";

	print ACTION "'restart')\n";
	print ACTION "\t$config_directory/stop && $config_directory/start\n";
	print ACTION "\tRETVAL=\$?\n";
	print ACTION "\t;;\n";

	print ACTION "*)\n";
	print ACTION "\techo \"Usage: \$0 { start | stop }\"\n";
	print ACTION "\tRETVAL=1\n";
	print ACTION "\t;;\n";
	print ACTION "esac\n";
	print ACTION "exit \$RETVAL\n";
	close(ACTION);
	chmod(0755, $fn);
	foreach $s (@start) {
		&add_rl_action($product, $s, "S", $start_order);
		}
	print STDERR "Created init script $fn\n";
	}

