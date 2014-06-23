#!/usr/bin/perl

use strict;
use XML::Simple;
use LWP::UserAgent;
use HTTP::Request;
use URI;
use Device::SerialPort;
use Time::HiRes;

#my $lcd_dev = '/dev/ttyACM1'; # Raspberry Pi
my $lcd_dev = '/dev/tty.usbmodem1411'; # Mac
my $api_key = 'you must supply your own key';
print $api_key."\n"; exit 0;

# Route 1 - East Bound
my $route1_label = 'EB'; # East Bound
my $route1_route = 'MTA NYCT_M14D';
my $route1_stop = 401579;

# Route 2 - West Bound
my $route2_label = 'WB'; # West Bound
my $route2_route = 'MTA NYCT_M14D';
my $route2_stop = 403893;

my $agent = 'lcdBusTime.pl [20140623] by Brian Czapiga / github.com/brianczapiga';
my $mta_url = 'http://bustime.mta.info/api/siri/stop-monitoring.xml';
my $xs = new XML::Simple;

# This is more of a splash screen than anything else...
my $textBuffer = "  Loading Data   Please Wait... ";

$SIG{'INT'} = sub { exit 0 };

sub getStopXML {
    my $gSX_key   = shift(@_);
    my $gSX_stop  = shift(@_);
    my $gSX_route = shift(@_);
    my $ua = LWP::UserAgent->new(
                 agent => $agent,
             );

    my $url = URI->new($mta_url);
    $url->query_form(
        'key'           => $gSX_key,
        'MonitoringRef' => $gSX_stop,
        'LineRef'       => $gSX_route,
    );

    my $req = HTTP::Request->new('GET', $url);

    my $res = $ua->request($req);

    if ($res->is_success) {
        return $res->content;
    }
    return undef;
}

sub distanceData {
    my $xml_data = getStopXML(@_);
    if ($xml_data =~ /PresentableDistance/i) {
        my $hash_ref = $xs->XMLin($xml_data);
        my $vehicles = ${$hash_ref}{'ServiceDelivery'}{'StopMonitoringDelivery'}{'MonitoredStopVisit'};
        my @vehicles;
        if (ref($vehicles) eq 'ARRAY') {
            foreach my $vehicle (@{$vehicles}) {
                my $distance = ${$vehicle}{'MonitoredVehicleJourney'}{'MonitoredCall'}{'Extensions'}{'Distances'}{'PresentableDistance'};
                $distance =~ s/at/\@/g;
                $distance =~ s/approaching$/\@st/g;
                $distance =~ s/ away$//g;
                $distance =~ s/ stops*/st/g;
                $distance =~ s/ miles/mi/g;
                push(@vehicles, $distance);
                last if ($#vehicles == 1);
            }
        } elsif (ref($vehicles) eq 'HASH') {
            my $distance = ${$vehicles}{'MonitoredVehicleJourney'}{'MonitoredCall'}{'Extensions'}{'Distances'}{'PresentableDistance'};
            $distance =~ s/at/\@/g;
            $distance =~ s/ away$//g;
            $distance =~ s/approaching$/\@st/g;
            $distance =~ s/ stops*/st/g;
            $distance =~ s/ miles/mi/g;
            push(@vehicles, $distance);
        }
        return join(" ",@vehicles);
    } elsif (length($xml_data)<=0) {
        return "No Data";
    } else {
        return "No Buses";
    }
}

sub rampColor {
    my $port = shift(@_);
    my $color1 = shift(@_);
    my $color2 = shift(@_);

    my ($r1,$g1,$b1) = unpack('C*', $color1);
    my ($r2,$g2,$b2) = unpack('C*', $color2);
    my ($r3,$g3,$b3) = ($r1,$g1,$b1);

    # Distance
    my $rDist = $r1-$r2; if ($rDist<0) { $rDist *= -1; }
    my $gDist = $g1-$g2; if ($gDist<0) { $gDist *= -1; }
    my $bDist = $b1-$b2; if ($bDist<0) { $bDist *= -1; }

    # Largest Distance
    my $lDist = ($rDist > $gDist ? $rDist : $gDist);
    $lDist = ($bDist > $lDist ? $bDist : $lDist);

    # Calculate Increments
    my $rInc = ($rDist/$lDist); if ($r1 > $r2) { $rInc *= -1; }
    my $gInc = ($gDist/$lDist); if ($g1 > $g2) { $gInc *= -1; }
    my $bInc = ($bDist/$lDist); if ($b1 > $b2) { $bInc *= -1; }

    # Set color
    my $color = pack('C*', int($r3), int($g3), int($b3));
    $port->write("\xFE\xD0".$color);

    while(1) {
        $r3 += $rInc if ($r2!=int($r3));
        $g3 += $gInc if ($g2!=int($g3));
        $b3 += $bInc if ($b2!=int($b3));
        # Set color
        $color = pack('C*', int($r3), int($g3), int($b3));
        $port->write("\xFE\xD0".$color);
        if (($r2==int($r3))&&
            ($g2==int($g3))&&
            ($b2==int($b3))) {
            last;
        }
        Time::HiRes::usleep(6250);
    }
}

my $PortObj;
unless($PortObj = new Device::SerialPort($lcd_dev)) {
    print STDERR "Could not open serial port: ".$!."\n";
}

# Set Baud Rate
$PortObj->baudrate(9600);

# Set LCD size
$PortObj->write("\xFE\x43");

# Auto Line Wrap
$PortObj->write("\xFE\x43");

# Disable Auto Scroll
$PortObj->write("\xFE\x52");

# Clear Screen
$PortObj->write("\xFE\x58");

my $red = "\xFF\x00\x00";
my $green = "\x00\xFF\x00";
my $yellow = "\xFF\xFF\x00";
my $blue = "\x00\x00\xFF";
my $setColor = "\xFE\xD0";

# Half Brightness
#$PortObj->write("\xFE\x99\x40");
# Contrast 220
#$PortObj->write("\xFE\x50\xDC");

# Default Screen
$PortObj->write($setColor);
$PortObj->write($blue);
# Home
$PortObj->write("\xFE\x48");
$PortObj->write("  Loading Data  \n Please Wait... ");
sleep 5;

my $route1_text;
my $route2_text;
my $updateTime = time - 15;
my $curColor = $blue;
my $cursor = ' ';

while(1) {
    $PortObj->write("\xFE\x47\x10\x02*");
    if ($updateTime <= (time-15)) {
        $route1_text = sprintf(
                                   $route1_label." %-13s",
                                   distanceData(
                                       $api_key,
                                       $route1_stop,
                                       $route1_route
                                   )
                              );
        $route2_text = sprintf(
                                   $route2_label." %-13s",
                                   distanceData(
                                       $api_key,
                                       $route2_stop,
                                       $route2_route
                                   )
                              );
        $updateTime = time;
        $PortObj->write("\xFE\x48");
        $PortObj->write($route1_text);
        $PortObj->write($route2_text);
    }
    if ($route1_text =~ /No Data/i) {
        if ($curColor ne $yellow) {
            rampColor($PortObj, $curColor, $yellow);
            $curColor = $yellow;
        }
    } elsif ((($route1_text =~ /st/i)&&($route1_text !~ /[12|\@]st/))||
             $route1_text =~ /\b0\.[0-8]mi\b/) {
      # Route 1 contains distance in stops and is less than 1 stop away
      # Route 1 contains a distance under 0.8 miles
        if ($curColor ne $green) {
            rampColor($PortObj, $curColor, $green);
            $curColor = $green;
        }
    } else {
      # Red if everything else is functioning normally
        if ($curColor ne $red) {
            rampColor($PortObj, $curColor, $red);
            $curColor = $red;
        }
    }

    # Blink the server
    if ($cursor eq '.') {
        $cursor = ' ';
    } elsif ($cursor eq ' ') {
        $cursor = '.';
    }
    $PortObj->write("\xFE\x47\x10\x02".$cursor);

    sleep 1;
}
