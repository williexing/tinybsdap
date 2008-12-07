#!/usr/bin/perl
# save_policy.cgi
# Change the default policy for some chain

require './firewall-lib.pl';
&ReadParse();
@tables = &get_iptables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});

if ($in{'add'}) {
	# Redirect to the rule page for adding a rule
	&redirect("edit_rule.cgi?table=$in{'table'}&chain=$in{'chain'}&new=1");
	}
elsif ($in{'delete'} && $in{'confirm'}) {
	# Delete this entire chain and all rules in it
	&lock_file($iptables_save_file);
	$table->{'rules'} = [ grep { $_->{'chain'} ne $in{'chain'} }
				   @{$table->{'rules'}} ];
	delete($table->{'defaults'}->{$in{'chain'}});
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($iptables_save_file);
	&webmin_log("delete", "chain", undef, { 'chain' => $in{'chain'},
						'table' => $table->{'name'} });
	&redirect("index.cgi?table=$in{'table'}");
	}
elsif ($in{'clear'} && $in{'confirm'}) {
	# Delete all rules from this chain
	&lock_file($iptables_save_file);
	$table->{'rules'} = [ grep { $_->{'chain'} ne $in{'chain'} }
				   @{$table->{'rules'}} ];
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($iptables_save_file);
	&webmin_log("clear", "chain", undef, { 'chain' => $in{'chain'},
					       'table' => $table->{'name'} });
	&redirect("index.cgi?table=$in{'table'}");
	}
elsif ($in{'delete'} || $in{'clear'}) {
	# Ask for confirmation on deleting the chain
	$mode = $in{'delete'} ? "delete" : "clear";
	&ui_print_header(undef, $text{$mode.'_title'}, "");

	@rules = grep { $_->{'chain'} eq $in{'chain'} } @{$table->{'rules'}};
	print "<form action=save_policy.cgi>\n";
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	print "<input type=hidden name=chain value='$in{'chain'}'>\n";
	print "<input type=hidden name=$mode value=1>\n";
	print "<center><b>",&text($mode.'_rusure', "<tt>$in{'chain'}</tt>",
				  scalar(@rules)),"</b><p>\n";
	print "<input type=submit name=confirm value='$text{'delete_ok'}'>\n";
	print "</center></form>\n";

	&ui_print_footer("index.cgi?table=$in{'table'}", $text{'index_return'});
	}
else {
	# Change the default for this chain
	&lock_file($iptables_save_file);
	$table->{'defaults'}->{$in{'chain'}} = $in{'policy'};
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($iptables_save_file);
	&webmin_log("modify", "chain", undef, { 'chain' => $in{'chain'},
					        'table' => $table->{'name'} });
	&redirect("index.cgi?table=$in{'table'}");
	}

