#!/usr/bin/perl -w
use strict;
use LWP::Simple;
use Data::Dumper;
use XML::Simple qw(:strict);

my @latlon = getLatLonfromZip('73007');
print "Latitude: $latlon[0]  Longitude: $latlon[1]\n";
sub getLatLonfromZip {
    my $zipcode = shift;
    my $url = 'http://graphical.weather.gov/xml/SOAP_server/ndfdXMLclient.php?whichClient=LatLonListZipCode&listZipCodeList=';
    $url .= "$zipcode" . '&Unit=e&Submit=Submit';
#    42420&Unit=e&Submit=Submit';
    my $xml = get($url);
    my $xs = XML::Simple->new(ForceArray => 1, KeyAttr => []);
    my $latlon = $xs->XMLin($xml);
 #   print Dumper $latlon;
    my $l = $latlon->{latLonList}[0];
    my @latlon = split /,/,$l;
#    print "Latitude: $latlon[0]  Longitude: $latlon[1]\n";
    return @latlon;
}