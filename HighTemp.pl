#!/usr/bin/perl -w
use strict;
use CGI;

my $cgi = new CGI;

open IMAGE, "<", "HighTemp.png";
my $size = -s "HighTemp.png";
read IMAGE, $data, $size;
close IMAGE;

print $cgi->header(-type=>'HighTemp.png');

exit;

