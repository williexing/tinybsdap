#!/usr/local/bin/perl
# save_categories.cgi

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'categories_err'});

# Save built-in categories
foreach $t (keys %text) {
	$t =~ s/^category_// || next;
	if (!$in{"def_$t"}) {
		$in{"desc_$t"} ||
			&error(&text('categories_edesc', $t ? $t : 'other'));
		$catnames{$t} = $in{"desc_$t"};
		}
	}

# Save custom categories
for($i=0; defined($in{"cat_$i"}); $i++) {
	if ($in{"cat_$i"} && $in{"desc_$i"}) {
		$realcat{$in{"cat_$i"}} &&
			&error(&text('categories_ecat', $in{"cat_$i"}));
		$catnames{$in{"cat_$i"}} = $in{"desc_$i"};
		}
	}

&lock_file("$config_directory/webmin.catnames");
&write_file("$config_directory/webmin.catnames", \%catnames);
&unlock_file("$config_directory/webmin.catnames");
&webmin_log("categories", undef, undef, \%in);
&flush_webmin_caches();
&redirect("");
