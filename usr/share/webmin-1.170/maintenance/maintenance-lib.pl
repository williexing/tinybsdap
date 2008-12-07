# infrastructure-lib.pl
# Functions for setting up network infrastructure
# -- 	mainly holds place to maintain webmin structures

do '../web-lib.pl';

# 	-- Property file manipulation
do '../web-lib-props.pl';		

&init_config();
require '../ui-lib.pl';
