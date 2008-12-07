#!/usr/local/bin/perl
# Re-start Webmin

require './webmin-lib.pl';

&restart_miniserv();
&redirect("");


