#!/usr/bin/perl -w
use strict;
use CGI;

my $cgi = new CGI;
my ($data, $size);

open IMAGE, "<", "3hrtmpdp.png";
$size = -s "3hrtmpdp.png";
read IMAGE, $data, $size;
close IMAGE;

print $cgi->header(-type=>'3hrtmpdp.png'), $data;

exit;

