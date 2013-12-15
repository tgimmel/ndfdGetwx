#!/usr/bin/perl -w
use strict;
use Weather::NWS::NDFDgen;
use Data::Dumper;
use XML::Simple qw(:strict);
use LWP::Simple qw(!head);
use feature qw/say/;
use Getopt::Std;
use GD::Graph::linespoints;
use GD::Text;
use CGI qw(:standard);

our ($opt_d);
getopts('d');


$Data::Dumper::Indent = 3;
my ($start_t, $end_t, $debug, $c, $d, $timekey, $inzip, $inctyst);
if ($opt_d) { $debug = 1 };
#$debug = 1;
my $q = CGI->new();
print $q->header(-title => 'Weather Temps',
);

print $q->start_html(-title => 'Weather Tempertures',
                   -BGCOLOR => '#0F7FBA',
);
$start_t = scalar localtime(time);
print "<div align=\"center\"><h1> Weather Temps Next 6 Days</h1>";
print "<h3>$start_t</h3></div>";
print "<hr>";
print $q->start_form();
print "Enter your <b>Zip Code</b>:<br> ";
print textfield(-name => 'inzip',
             -default => '42458',
                -size => 20,
           -maxlength => 5,
);
print '<br>';
#print "<br>Or Enter your <b>City, State:</b><br>";
#print textfield( -name => 'inctyst',
#                 -size => '20',
#              -maxlength => 20,
#);
$inzip   = param('inzip');
#$inctyst = param('inctyst');

#print "<br>";
print submit(-name => 'submitZip',
            -label => 'Get Weather',
);
if (!param()) { exit; }   #This hits the first time around!
print $q->end_form();
unless ($inzip =~ /^[0-9]{5}$/) { say "Sorry Try again, Zip Code Error!"; }
#say $inctyst;
#Put Zip in the log
say STDERR "ZipCode:$inzip";
#my ($incity, $instate) = split /,/, $inctyst;
#end new citystate
say "<br>inzip is $inzip" if $debug;

#$end_t = scalar localtime(time + 604800);    #7 days later
$end_t = scalar localtime(time + 518400);     #6 days later
if ($debug) {print "Scalar Start time: $start_t \n";}
if ($debug) {print "Scalar End Time: $end_t\n";}

my ($latitude, $longitude) = getLatLonfromZip($inzip);
my ($city, $state) = getCitybyZip($inzip);
if ($city eq undef || $state eq undef) { $city = 'Unknown'; $state = 'Unknown'; }

if ($debug) { say "Latitude: $latitude Longitude: $longitude"; }
if ($debug) { say "City : $city State: $state"; }

my $ndfdgen = Weather::NWS::NDFDgen->new();
#($latitude, $longitude) = ('37.8531', '-87.4455');  #Home

$ndfdgen->set_latitude($latitude);
$ndfdgen->set_longitude($longitude);
my $product = 'Time-Series';
$ndfdgen->set_product($product) or die;
$ndfdgen->set_start_time($start_t) or die;
$ndfdgen->set_end_time($end_t) or die;

$ndfdgen->set_weather_parameters(
            'Maximum Temperature' => 1,
            'Minimum Temperature' => 1,
           'Dewpoint Temperature' => 1,
              'Relative Humidity' => 1,
           '3 Hourly Temperature' => 1,
             'Cloud Cover Amount' => 1,
                     'Wind Speed' => 1,
);


my $xml = $ndfdgen->get_forecast_xml();
if ($debug) { print Dumper $xml};
my $xs = XML::Simple->new(ForceArray => 1, KeyAttr => []);

my $forcast = $xs->XMLin($xml);
if ($debug) { print Dumper $forcast };
#say Dumper $forcast;
#my $s = @{$forcast->{data}[0]->{parameters}[0]->{temperature}[2]->{value}};
my $params = $forcast->{data}[0]->{parameters}[0]->{temperature};

my $ht          = $params->[0]->{value};                            #Max Daily Temp
my $ht_time     = $params->[0]->{'time-layout'};
my $lt          = $params->[1]->{value};                           #Min Daily Temp
my $lt_time     = $params->[1]->{'time-layout'};
my $hrtmp       = $params->[2]->{value};                      #3Hour Temperature
my $hrtmp_time  = $params->[2]->{'time-layout'};
my $dp          = $params->[3]->{value};                         #3Hourly Dewpoint
my $dp_time     = $params->[3]->{'time-layout'};
my $hd          = $forcast->{data}[0]->{parameters}[0]->{humidity}[0]->{value};          #3Hour Humidity
my $hd_time     = $forcast->{data}[0]->{parameters}[0]->{humidity}[0]->{'time-layout'};
my $cldamt      = $forcast->{data}[0]->{parameters}[0]->{'cloud-amount'}[0]->{value};
my $cldamt_time = $forcast->{data}[0]->{parameters}[0]->{'cloud-amount'}[0]->{'time-layout'};
my $time        = $forcast->{data}[0]->{'time-layout'};                                #Time Layout hash base
my $moreInfo    = $forcast->{data}[0]->{moreWeatherInformation}[0]->{content};
my $windspeed   = $forcast->{data}[0]->{parameters}[0]{'wind-speed'}[0]->{value};
my $windspeed_time = $forcast->{data}[0]->{parameters}[0]{'wind-speed'}[0]->{'time-layout'};
my $svt;        #$svt is Start Valid Time

if ($debug) {
    say "Hi temp time layout $ht_time";
    say "Low temp time layout $lt_time";
    say "3 hour temp time layout $hrtmp_time";
    say "3 hour dewpoint time layout $dp_time";
    say "Humidity temp time layout $hd_time";
    say "Wind Speed time layout $windspeed_time";
}
my %timeinfo;

for ($c = 0; $c <= @{$time} - 1; $c++) {
    say $time->[$c]->{'layout-key'}[0] . "<br>" if ($debug);         #This is the Time Key at @c
    $timekey = $time->[$c]->{'layout-key'}[0];
    $svt = $time->[$c]->{'start-valid-time'};                        #iterate over times
    $timeinfo{$timekey} = [] unless $timeinfo{$timekey};
    for ($d = 0; $d <= @{$svt} - 1; $d++) {
        say $svt->[$d] . "<br>" if ($debug);                         #each of the time codes
        my $t = $svt->[$d];
        $t =~ /\d{4}-(\d{2}-\d{2})T(\d{2}:\d{2}):00-\d{2}:00/;
        $t = $1 . " " . $2;
        push (@{$timeinfo{$timekey}}, $t);                           #list of Time Codes with times
    }
}
say "<br>";
if ($debug) {
    say "Time Info";
    print Dumper %timeinfo;
}
my (@hitemp, @lowtemp, @hrlytmp, @hrlydp, @hrlyhd, @hitemp_time, @lotemp_time, @hrlytmp_time, @cldamt, @hilowtempHeader);
my (@windspd, @windspd_time);
my $k = 0;
my $s = @{$ht};
unless (!$debug) { print "Scaler $s\n"; }
print "Next $s Day Highs <br>\n" if ($debug);
for ($c = 0; $c <= (@{$ht} - 1); $c++) {
    print "@{$timeinfo{$ht_time}}[$c] " if $debug;
    say "$ht->[$c]F  <br>" if $debug;
    push(@hitemp, $ht->[$c]);
    push(@hitemp_time, @{$timeinfo{$ht_time}}[$c]);
}

    my $l = @{$lt};   #number of days
    print "Next $l day Lows <br>\n" if $debug;
    for ($c = 0; $c <= (@{$lt} - 1); $c++) {
        print "@{$timeinfo{$lt_time}}[$c] " if $debug;
        say "$lt->[$c]F <br>" if $debug;
        push (@lowtemp, $lt->[$c]);
        push (@lotemp_time, @{$timeinfo{$lt_time}}[$c]);
    }
#Here we work out header issues.  Somtimes there is not
#the same amount of High and Low Temps depending on the time
#of Day.
@hilowtempHeader = @hitemp_time;    #Default use Hitemp time/date/temp
my ($p,$r);
$p = @hitemp_time;
$r = @lotemp_time;
print "p is $p and r is $r\n" if $debug;
if ($p < $r) {
    unshift(@hitemp, undef);
    @hilowtempHeader = @lotemp_time;
}

print "\n";
print "3 Hourly Temperature <br>\n" if $debug;
for ($c = 0; $c <= (@{$hrtmp} - 1); $c++) {
    print "@{$timeinfo{$hrtmp_time}}[$c] " if $debug;
    $k++;
    print "$hrtmp->[$c] F  " if $debug;
    if ($k == 4) {
        print "<br>\n" if $debug;
        $k = 0;
    }
    push(@hrlytmp, $hrtmp->[$c]);
    push(@hrlytmp_time, @{$timeinfo{$hrtmp_time}}[$c]);
}
if ($debug) {
   say "3 Hourly temp codes";
   print Dumper @hrlytmp_time;
   say "3 Hourly temps";
   print Dumper @hrlytmp;
}
print "\n";
print "3 Hourly Dewpoint <br>\n" if $debug;
$k = 0;
for ($c = 0; $c <= (@{$dp} - 1); $c++) {
    print "@{$timeinfo{$dp_time}}[$c] " if $debug;
    $k++;
    print "$dp->[$c] F  " if $debug;
    if ($k == 4) {
        print " <br>\n" if $debug;
        $k = 0;
    }
    push(@hrlydp, $dp->[$c]);
}
print "3 Hourly Humidity <br>\n" if $debug;
$k = 0;
for ($c = 0; $c <= (@{$hd} - 1); $c++) {
    print "@{$timeinfo{$hd_time}}[$c] " if $debug;
    $k++;
    print "$hd->[$c] F  " if $debug;
    if ($k == 4) {
        print "<br>\n" if $debug;
        $k = 0;
    }
    push(@hrlyhd, $hd->[$c]);
}
$k =  0;
say "% cloud coverage <br>" if $debug;
for ($c = 0; $c <= (@{$cldamt} - 1); $c++) {
    print "@{$timeinfo{$cldamt_time}}[$c] " if $debug;
    $k++;
    print "$cldamt->[$c]%  " if $debug;
    if ($k == 4) {
        print "<br>\n" if $debug;
        $k = 0;
    }
    push(@cldamt, $cldamt->[$c]);
}
$k = 0;
say "Wind Speed <br>" if $debug;
for ($c =0; $c <= (@{$windspeed} -1); $c++) {
    print "@{$timeinfo{$windspeed_time}}[$c] " if $debug;
    $k++;
    print "$windspeed->[$c] mph " if $debug;
    if ($k == 4) {
        print "<br>\n" if $debug;
        $k = 0;
   }
   push(@windspd, $windspeed->[$c]);
}

my $font_dir = '/usr/share/fonts';
my $font_file = "$font_dir/truetype/freefont/FreeSans.ttf";

my @data = (
    [@hilowtempHeader],
    [@hitemp],
    [@lowtemp],
  );
if ($debug) { print Dumper @data; }
my $graph = GD::Graph::linespoints->new(640, 480);
$graph->set(
      x_label           => 'Date-Time',
      y_label           => 'Temperature',
      title             => "Zip Code: $inzip  Lat: $latitude Long: $longitude",
      y_max_value       => 100,
      transparent       => 0,
      y_tick_number     => 8,
      bgclr             => 'white',
      show_values       => 1,
      long_ticks        => 1,
      legend_placement  => 'RC',
   legend_marker_width  => 12,
   legend_marker_height => 12,
      markers           => [ 1, 5 ],
  ) or die $graph->error;
my $cando_ttf = $graph->can_do_ttf();
if (!$cando_ttf) { print STDERR "WARNING: Cannot render trueType fonts!\n"; }

$graph->set_legend( 'High Temp', 'Low Temp');
$graph->set_title_font($font_file, 14);
$graph->set_x_label_font($font_file, 10);
$graph->set_y_label_font($font_file, 12);
$graph->set_x_axis_font($font_file, 8);
$graph->set_y_axis_font($font_file, 10);
$graph->set_legend_font($font_file, 9);
my $gd = $graph->plot(\@data) or die $graph->error;
open(IMG, ">", 'HighTemp.png') or die $!;
  binmode IMG;
  print IMG $gd->png;
  close IMG;

my @data2 = (
    [@hrlytmp_time],
    [@hrlytmp],
    [@hrlydp],
    [@hrlyhd],
    [@cldamt],
    [@windspd],
);
if ($debug) { print Dumper @data2; }
my $graph2 = GD::Graph::linespoints->new(1000, 600);
$graph2->set(
      x_label           => 'Date-Time',
      y_label           => 'Temperature',
      title             => "Zip code: $inzip  Lat: $latitude, Long: $longitude",
      transparent       => 0,
      bgclr             => 'white',
      y_max_value       => 120,
      y_tick_number     => 8,
      show_values       => 1,
      x_labels_vertical => 1,
      line_types        => [ 1, 1, 2, 1, 1 ],
      markers           => [ 1, 5, 7, 1, 7 ],
      dclrs             => [ qw(red green blue cyan purple) ],
      long_ticks        => 1,
      legend_placement  => 'RC',
   legend_marker_width  => 12,
   legend_marker_height => 12
  ) or die $graph->error;
$graph2->set_legend('Temp', 'Dewpoint' , 'Humidity' , ' % Cloudcover', 'Wind Speed');

$graph2->set_title_font($font_file, 12);
$graph2->set_x_label_font($font_file, 10);
$graph2->set_y_label_font($font_file, 12);
$graph2->set_x_axis_font($font_file, 8);
$graph2->set_y_axis_font($font_file, 10);
$graph2->set_legend_font($font_file, 9);

my $gd2 = $graph2->plot(\@data2) or die $graph2->error;
open IMG, ">", "3hrtmpdp.png" or die;
binmode IMG;
print IMG $gd2->png;

my $mapuri = setmap($latitude, $longitude);
say STDERR $latitude, $longitude, $mapuri;
print <<EOB;
<div align=\"center\">
<h2>Next 7 Day High and Low Tempertures <br> $city,  $state</h2>
<p><img src="http://banger.gimmel.org:41959/cgi-bin/HighTemp.pl" style="border: #000000 2px solid;" "width="640" height="480" longdesc="HighTemp.png" /> 
<img src="$mapuri" style="border: #000000 1px solid;" width="400" height="480" longdesc="Map of Area"> </p>
<h2>3 Hour Tempertures, Dewpoints, Humidity, Percent Cloudcover and Windspeed <br> $city,  $state</h2>
<p><img src="http://banger.gimmel.org:41959/cgi-bin/3hrtmpdp.pl" style="border: #000000 2px solid;" "width="800" height="600" longdesc="3 hour temps" /> </p>
</div>
<!-- Clear Dark Sky image here -->
<a href=http://cleardarksky.com/c/EvnsvllINkey.html>
<img src="http://cleardarksky.com/c/EvnsvllINcs0.gif?1"></a>
<br>
EOB

print "<b><a href=$moreInfo>More Weather information for this location here.</a></b><br>";

print <<EOB;
<hr><br>
Data Courtesy of National Weather Service, http://www.nws.noaa.gov/ndfd
<br>
Send Email and comments to: webmaster at gimmel.org
<br>
<i>Copyright &copy; 2013, Tim Gimmel, Henderson, KY 42420</i>
<br>
<i>Last modified 28-Nov-2013</i>
EOB

print $q->end_html();

sub getWxdata {            #Not used yet, under heavy construction
    my ($timeinfo, $wxcdx) = @_;
    my ($c, $k); 
    print "3 Hourly Dewpoint <br>\n" if $debug;
    $k = 0;
    for ($c = 0; $c <= (@{$dp} - 1); $c++) {
        print "@{$timeinfo{$dp_time}}[$c] " if $debug;
        $k++;
        print "$dp->[$c] F  " if $debug;
        if ($k == 4) {
            print " <br>\n" if $debug;
            $k = 0;
        }  
    #    push(@hrlydp, $dp->[$c]);
    }
}

####################################
# Sub getLatLonfromZip
# Returns an array with Latitude and Longitude
# Call with Zipcode String
#
sub getLatLonfromZip {
    say STDERR "Im in getLatLonfromZip";
    my $zipcode = shift;
    my $url = 'http://graphical.weather.gov/xml/SOAP_server/ndfdXMLclient.php?whichClient=LatLonListZipCode&listZipCodeList=';
    $url .= "$zipcode" . '&Unit=e&Submit=Submit';
    my $xml = get($url);
    my $xs = XML::Simple->new(ForceArray => 1, KeyAttr => []);
    my $latlon = $xs->XMLin($xml);
    my $l = $latlon->{latLonList}[0];
    say STDERR "getLatLonfromZip: Here is lat/lon $l";
    my @latlon = split /,/,$l;
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
    my $xml = get($url);
    my $xz = XML::Simple->new(ForceArray => 1, KeyAttr => []);
    my $city = $xz->XMLin($xml);
    my $cty = $city->{Table}[0]->{CITY}[0];
    my $st  = $city->{Table}[0]->{STATE}[0];
    ($cty, $st);
}

sub setmap {
   my $lat = shift;
   my $lon = shift;
    my $mapuri  = 'http://maps.googleapis.com/maps/api/staticmap?center=';
    $mapuri .= $lat . ",";
    $mapuri .= $lon;
    $mapuri .= '&zoom=11&size=400x480&visual_refresh=%22true%22&scale=1&markers=';
    $mapuri .= $lat . ",";
    $mapuri .= $lon . '&key=AIzaSyCo7-PwfPV1mbghcb1FGmwE6SAl-xL_Y14&sensor=false';
    return $mapuri;
}

__END__
Products:
$VAR1 = 'Glance';
$VAR2 = 'Time-Series';

Weather Params:
$VAR1 = 'Glance';
$VAR2 = 'Time-Series';
$VAR1 = 'Wind Direction';
$VAR2 = 'Cloud Cover Amount';
$VAR3 = 'Weather Icons';
$VAR4 = '12 Hour Probability of Precipitation';
$VAR5 = '3 Hourly Temperature';
$VAR6 = 'Weather';
$VAR7 = 'Relative Humidity';
$VAR8 = 'Liquid Precipitation Amount';
$VAR9 = 'Minimum Temperature';
$VAR10 = 'Apparent Temperature';
$VAR11 = 'Wind Speed';
$VAR12 = 'Wave Height';
$VAR13 = 'Snowfall Amount';
$VAR14 = 'Maximum Temperature';
$VAR15 = 'Dewpoint Temperature';
