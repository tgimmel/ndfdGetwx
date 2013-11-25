#!/usr/bin/perl -w
use strict;
use LWP::Simple;
use Data::Dumper;
use XML::Simple qw(:strict);

$Data::Dumper::Indent = 3;
my @latlon = getLatLonfromZip('42420');
my @cityst = getCitybyZip('42420') or die;
print "Latitude: $latlon[0]  Longitude: $latlon[1]\n";
print "City: $cityst[0], ST: $cityst[1]\n";

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

#####################################
# Sub GetCitybyZip
# Return array with City and State
# Call with ZipCode String
# Retrun undef on bad zipcode string
# Uses www.webservx.net to get data.
#
sub getCitybyZip {
    my $zipcode = shift;
    unless ($zipcode =~ /^[0-9]{5}$/) { print STDERR "getCitybyZip:zip code format error!\n"; return undef; }
    my $url = 'http://www.webservicex.net/uszip.asmx/GetInfoByZIP?USZip=';
    $url .= "$zipcode"; 
    print "$url \n";
    my $xml = get($url);
    my $xz = XML::Simple->new(ForceArray => 1, KeyAttr => []);
    my $city = $xz->XMLin($xml);
    print Dumper $city;
    my $cty = $city->{Table}[0]->{CITY}[0];
    my $st  = $city->{Table}[0]->{STATE}[0];
    ($cty, $st);
}
