#!/usr/bin/perl -w
use strict;
use Weather::NWS::NDFDgen;
use Data::Dumper;
use XML::Simple qw(:strict);
use feature qw/say/;
use Getopt::Std;
use GD;
use GD::Graph::linespoints;
use GD::Text;
use CGI qw(:standard);

our ($opt_d);
getopts('d');


$Data::Dumper::Indent = 3;
my ($start_t, $end_t, $debug, $c, $d, $timekey);
if ($opt_d) { $debug = 1 };

my $q = CGI->new();
print $q->header(-title => 'Weather Temps');
print $q->start_html(-title => 'Weather Tempertures',
                   -BGCOLOR => 'grey',
);
print "\n";
#print Dumper @rawtime;
$start_t = scalar localtime(time);
#$end_t = scalar localtime(time + 604800);   #7 days later
$end_t = scalar localtime(time + 432000);   #5 days later
#$end_t = scalar localtime(time + 259200);   #3 days later
if ($debug) {print "Scalar Start time: $start_t \n";}
if ($debug) {print "Scalar End Time: $end_t\n";}

my $ndfdgen = Weather::NWS::NDFDgen->new();
#my ($latitude, $longitude) = ('37.8531', '-87.4455');  #Home
my ($latitude, $longitude) = ('37.84', '-87.59');
#my ($latitude, $longitude) = ('37.5467', '-87.9839'); #Stugis, KY
#my @products = $ndfdgen->get_available_products();
#my @weather_params = $ndfdgen->get_available_weather_parameters();

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
);


my $xml = $ndfdgen->get_forecast_xml();
if ($debug) { print Dumper $xml};
my $xs = XML::Simple->new(ForceArray => 1, KeyAttr => []);

my $forcast = $xs->XMLin($xml);
if ($debug) { print Dumper $forcast };
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
my $svt;        #$svt is Start Valid Time

if ($debug) {
    say "Hi temp time layout $ht_time";
    say "Low temp time layout $lt_time";
    say "3 hour temp time layout $hrtmp_time";
    say "3 hour dewpoint time layout $dp_time";
    say "Humidity temp time layout $hd_time";
}
my %timeinfo;

for ($c = 0; $c <= @{$time} - 1; $c++) {
    say $time->[$c]->{'layout-key'}[0] . "<br>";              #This is the Time Key at @c
    $timekey = $time->[$c]->{'layout-key'}[0];
    $svt = $time->[$c]->{'start-valid-time'};        #iterate over times
    $timeinfo{$timekey} = [] unless $timeinfo{$timekey};
    for ($d = 0; $d <= @{$svt} - 1; $d++) {
        say $svt->[$d] . "<br>";                              #each of the time codes
        my $t = $svt->[$d];
        $t =~ /\d{4}-(\d{2}-\d{2})T(\d{2}:\d{2}):00-\d{2}:00/;
        $t = $1 . " " . $2;
        push (@{$timeinfo{$timekey}}, $t);            #list of Time Codes with times
    }
}
say "<br>";
if ($debug) {
    say "Time Info";
    print Dumper %timeinfo;
}
my (@hitemp, @lowtemp, @hrlytmp, @hrlydp, @hrlyhd, @hitemp_time, @lotemp_time, @hrlytmp_time, @cldamt, @hilowtempHeader);
my $k = 0;
my $s = @{$ht};
unless (!$debug) { print "Scaler $s\n"; }
print "Next $s Day Highs <br>\n";
for ($c = 0; $c <= (@{$ht} - 1); $c++) {
    print "@{$timeinfo{$ht_time}}[$c] ";
    say "$ht->[$c]F  <br>";
    push(@hitemp, $ht->[$c]);
    push(@hitemp_time, @{$timeinfo{$ht_time}}[$c]);
}
print "<br>\n";


    my $l = @{$lt};   #number of days
    print "Next $l day Lows <br>\n";
    for ($c = 0; $c <= (@{$lt} - 1); $c++) {
        print "@{$timeinfo{$lt_time}}[$c] ";
        say "$lt->[$c]F <br>";
        push (@lowtemp, $lt->[$c]);
        push (@lotemp_time, @{$timeinfo{$lt_time}}[$c]);
    }
say "<br>";
@hilowtempHeader = @hitemp_time;    #Default use Hitemp time/date/temp
if (substr($lowtemp[0], 0, 4) lt substr($hitemp[0], 0, 4)) {     #HiTemp for the day has passed, so the
        unshift(@hitemp, undef);                                 #First HiTemp is tomorrow, We unshift him away.
        #push(@hitemp, undef);
        @hilowtempHeader = @lotemp_time;                       #Since the default Header is High Temp it will
        #print Dumper @hitemp;                                  #start with tomorrow, but todays low is forcast at
}                                                              #at 19:00, so use Low Temps Date/Times
print "\n";
print "3 Hourly Temperature <br>\n";
for ($c = 0; $c <= (@{$hrtmp} - 1); $c++) {
    print "@{$timeinfo{$hrtmp_time}}[$c] ";
    $k++;
    print "$hrtmp->[$c] F  ";
    if ($k == 4) {
        print "<br>\n";
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
print "3 Hourly Dewpoint <br>\n";
$k = 0;


    for ($c = 0; $c <= (@{$dp} - 1); $c++) {
        print "@{$timeinfo{$dp_time}}[$c] ";
        $k++;
        print "$dp->[$c] F  ";
        if ($k == 4) {
            print " <br>\n";
            $k = 0;
        }
        push(@hrlydp, $dp->[$c]);
    }

print "\n";
print "3 Hourly Humidity <br>\n";
$k = 0;

    for ($c = 0; $c <= (@{$hd} - 1); $c++) {
        print "@{$timeinfo{$hd_time}}[$c] ";
        $k++;
        print "$hd->[$c] F  ";
        if ($k == 4) {
            print "<br>\n";
            $k = 0;
        }
        push(@hrlyhd, $hd->[$c]);
    }

print "\n";
$k =  0;
say "% cloud coverage <br>";

    for ($c = 0; $c <= (@{$cldamt} - 1); $c++) {
        print "@{$timeinfo{$cldamt_time}}[$c] ";
        $k++;
        print "$cldamt->[$c]%  ";
        if ($k == 4) {
            print "<br>\n";
            $k = 0;
        }
        push(@cldamt, $cldamt->[$c]);
    }

#say "More Weather information at: $moreInfo\.";


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
      title             => "High and Low Temperatures for Lat: $latitude, Long: $longitude",
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
      #y_label_skip      => 2
  ) or die $graph->error;
my $cando_ttf = $graph->can_do_ttf();
if (!$cando_ttf) { print "<h2>WARNING: Cannot render trueType fonts!</h2><br>\n"; }

$graph->set_legend( 'High Temp', 'Low Temp');
$graph->set_title_font($font_file, 14);
$graph->set_x_label_font($font_file, 10);
$graph->set_y_label_font($font_file, 12);
$graph->set_x_axis_font($font_file, 8);
$graph->set_y_axis_font($font_file, 10);
$graph->set_legend_font($font_file, 9);
my $gd = $graph->plot(\@data) or die $graph->error;
open(IMG, '>/home/tim/perl/ndfdGetwx/HighTemp.png') or die $!;
  binmode IMG;
  print IMG $gd->png;
  close IMG;

my @data2 = (
    [@hrlytmp_time],
    [@hrlytmp],
    [@hrlydp],
    [@hrlyhd],
    [@cldamt],
);
if ($debug) { print Dumper @data2; }
my $graph2 = GD::Graph::linespoints->new(1000, 600);
$graph2->set(
      x_label           => 'Date-Time',
      y_label           => 'Temperature',
      title             => "Temperature, Dewpoint, Cloudcover and Humidity for Lat: $latitude, Long: $longitude",
      transparent       => 0,
      bgclr             => 'white',
      y_max_value       => 120,
      y_tick_number     => 8,
      show_values       => 1,
      x_labels_vertical => 1,
      line_types        => [ 1, 1, 2 ],
      markers           => [ 1, 5, 7, 1 ],
      dclrs             => [ qw( red green blue cyan) ],
      long_ticks        => 1,
      legend_placement  => 'RC',
   legend_marker_width  => 12,
   legend_marker_height => 12
      #y_label_skip      => 2
  ) or die $graph->error;
$graph2->set_legend('Temp', 'Dewpoint' , 'Humidity' , ' % Cloudcover');

$graph2->set_title_font($font_file, 12);
$graph2->set_x_label_font($font_file, 10);
$graph2->set_y_label_font($font_file, 12);
$graph2->set_x_axis_font($font_file, 8);
$graph2->set_y_axis_font($font_file, 10);
$graph2->set_legend_font($font_file, 9);

my $gd2 = $graph2->plot(\@data2) or die $graph2->error;
open IMG, ">", "/home/tim/perl/ndfdGetwx/3hrtmpdp.png" or die;
binmode IMG;
print IMG $gd2->png;
#close;


print <<EOB;
<br>
<h2>Next 7 Day High and Low Tempertures</h2>
<p><img src="http://banger.gimmel.org/cgi-bin/HighTemp.pl" "width="640" height="480" longdesc="HighTemp.png" />  </p>
<h2>3 Hour Tempertures, Dewpoints, Humidity and Percent Cloudcover</h2>
<p><img src="http://banger.gimmel.org/cgi-bin/3hrtmpdp.pl" "width="800" height="600" longdesc="3 hour temps" /> </p>
<br>
<a href="http://forecast.weather.gov/MapClick.php?textField1=37.85&textField2=-87.45">More Weather information for this location here.</a>
<br>
EOB


print $q->end_html();

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
