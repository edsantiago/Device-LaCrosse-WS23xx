# -*- perl -*-
#
# Open2300 - interface to La Crosse WS-23xx weather stations
#
# $Id: NIS.pm,v 1.10 2003/03/19 12:32:07 esm Exp $
#
package Open2300;

use strict;
use warnings;
use Carp;
use Time::Local;

(our $ME = $0) =~ s|^.*/||;

###############################################################################
# BEGIN user-customizable section

our $Values = <<'END_VALUES';
# Rainfall
Rain_24h	      mm	[0x0497:6] / 100.0
Rain_1h		      mm	[0x04B4:6] / 100.0
Rain_Total            mm	[0x04D2:6] / 100.0

# Wind info
Wind_Speed	      m/s	[0x0529:3]
Wind_Direction        degrees	[0x052C:1] * 22.5

# Logistics
Connection_Type	      string	[0x054D:1]

Countdown	      seconds	[0x054F:2] / 2.0
END_VALUES

# END   user-customizable section
###############################################################################

require Exporter;
require DynaLoader;
require AutoLoader;

use vars qw(@ISA %EXPORT_TAGS @EXPORT_OK @EXPORT);

@ISA = qw(Exporter DynaLoader);

%EXPORT_TAGS = ( );
@EXPORT_OK   = ( );
@EXPORT      = ( );

our $VERSION = '0.01';

our $PKG = __PACKAGE__;		# For interpolating into error messages

bootstrap Open2300 $VERSION;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $device = shift                     # in: mandatory arg
      or croak "Usage: ".__PACKAGE__."->new( \"/dev/LACROSS-DEV-NAME\" )";

    # FIXME: call xs code
    my $fh = open_2300($device)
	or die "cannot open\n";
    print "got here: fh=$fh\n";

    return bless {
		  path => $device,
		  fh   => $fh,
		 }, $class;
}


sub get {
    my $self  = shift;
    my $field = shift
      or croak "Usage: $PKG->new( FIELD )";

    $self->{fields} ||= do {
	my %fields;
	for my $line (<DATA>) {
	    next if $line =~ m!^\s*$!;		# Skip blank lines
	    next if $line =~ m!^\s*#!;		# Skip comments

	    $line =~ /^(\S+):(\S+)\s+(\S+)\s+(\S.*\S)/
	      or die "Internal error: Cannot grok '$line'";
	    $fields{lc $3} = {
#		units => $2,
		address => hex($1),
		count   => $2,
		name  => $3,
		expr  => $4,
	    };
	}

	\%fields;
    };

    my $get = $self->{fields}->{lc $field}
      or croak "$ME: No such value, '$field'";

    my @foo = read_2300($self->{fh}, $get->{address}, $get->{count});

    # Interpret
    my $BCD = join('', reverse(@foo));  $BCD =~ s/^0+//;
    print "BCD = '$BCD' (@foo)\n";
    my $HEX = hex($BCD);

    # Special case for datetime: return a unix time_t
    sub time_convert($) {
	#             YY      MM     DD    HH    MM
	$_[0] =~ m!^(\d{1,2})(\d\d)(\d\d)(\d\d)(\d\d)$!
	  or die "$ME: Internal error: bad datetime '$_[0]'";
	return timelocal( 0,$5,$4, $3, $2-1, $1+100);
    }

    my $expr = $get->{expr};
    if ($expr =~ /\d=.*,.*\d=/) {
	my @y;
	for my $pair (split(/\s*,\s*/, $expr)) {
	    $pair =~ /(\d+)=(.*)/ or die;
	    $y[$1] = $2;
	}

	my $val = $y[$BCD || 0];
	if (defined $val) {
	    return $val;
	}
	else {
	    return "undefined($BCD)";
	}
    }

    my $val = eval($get->{expr});
    if ($@) {
	croak "$ME: eval( $get->{expr} ) died: $@";
    }

    # Asked to convert?
    if (@_) {
	return unit_convert($val, $get->{units}, $_[0]);
    }
    return $val;
}


sub unit_convert {
    my $value     = shift;
    my $units_in  = shift;
    my $units_out = shift;

    if ($units_in eq 'degreesC') {
	if ($units_out =~ /^(deg(rees)?)?F$/) {
	    return $value * 9.0 / 5.0 + 32.0;
	}
    }

    elsif($units_in eq 'hPa') {
	if ($units_out =~ /^inhg$/i) {
	    return $value / 33.8638864;
	}
    }

    croak "$ME: Don't know how to convert $units_in to $units_out";
}

sub TIEARRAY {
    my $class = shift;
    my $ws    = shift;		# in: weatherstation object

}

###############################################################################

1;

__DATA__
000F:1  Wind_unit                           0=m/s, 1=knots, 2=beaufort, 3=km/h, 4=mph
0266:1  LCD_contrast                        $BCD+1 (Read Only: changing it has no impact on LCD.)
026B:1  Forecast                            0=Rainy, 1=Cloudy, 2=Sunny
026C:1  Tendency                            0=Steady, 1=Rising, 2=Falling
0346:3  Indoor_Temperature                  $BCD / 100.0 - 30
034B:3  Min_Indoor_Temperature              $BCD / 100.0 - 30
0350:3  Max_Indoor_Temperature              $BCD / 100.0 - 30
0354:9  Min_Indoor_Temperature_datetime     time_convert($BCD)
035E:9  Max_Indoor_Temperature_datetime     time_convert($BCD)
0369:3  Low_Alarm_Indoor_Temperature        $BCD / 100.0 - 30
036E:3  High_Alarm_Indoor_Temperature       $BCD / 100.0 - 30
0373:3  Outdoor_Temperature                 $BCD / 100.0 - 30
0378:3  Min_Outdoor_Temperature             $BCD / 100.0 - 30
037D:3  Max_Outdoor_Temperature             $BCD / 100.0 - 30
0381:9  Min_Outdoor_Temperature_datetime    time_convert($BCD)
038B:9  Max_Outdoor_Temperature_datetime    time_convert($BCD)
0396:3  Low_Alarm_Outdoor_Temperature       $BCD / 100.0 - 30
039B:3  High_Alarm_Outdoor_Temperature      $BCD / 100.0 - 30
03A0:3  Windchill                           $BCD / 100.0 - 30
03A5:3  Min_Windchill                       $BCD / 100.0 - 30
03AA:3  Max_Windchill                       $BCD / 100.0 - 30
03AE:9  Min_Windchill_datetime              yymmddhhmm($BCD)
03B8:9  Max_Windchill_datetime              yymmddhhmm($BCD)
03C3:3  Low_Alarm_Windchill                 $BCD / 100.0 - 30
03C8:3  High_Alarm_Windchill                $BCD / 100.0 - 30
03CE:3  Dewpoint                            $BCD / 100.0 - 30
03D3:3  Min_Dewpoint                        $BCD / 100.0 - 30
03D8:3  Max_Dewpoint                        $BCD / 100.0 - 30
03DC:9  Min_Dewpoint_datetime               time_convert($BCD)
03E6:9  Max_Dewpoint_datetime               time_convert($BCD)
03F1:3  Low_Alarm_Dewpoint                  $BCD / 100.0 - 30
03F6:3  High_Alarm_Dewpoint                 $BCD / 100.0 - 30
03FB:1  Indoor_Humidity                     $BCD
03FD:1  Min_Indoor_Humidity                 $BCD
03FF:1  Max_Indoor_Humidity                 $BCD
0401:9  Min_Indoor_Humidity_datetime        time_convert($BCD)
040B:9  Max_Indoor_Humidity_datetime        time_convert($BCD)
0415:1  Low_Alarm_Indoor_Humidity           $BCD
0417:1  High_Alarm_Indoor_Humidity          $BCD
0419:1  Outdoor_Humidity                    $BCD
041B:1  Min_Outdoor_Humidity                $BCD
041D:1  Max_Outdoor_Humidity                $BCD
041F:9  Min_Outdoor_Humidity_datetime       time_convert($BCD)
0429:9  Max_Outdoor_Humidity_datetime       time_convert($BCD)
0433:1  Low_Alarm_Outdoor_Humidity          $BCD
0435:1  High_Alarm_Outdoor_Humidity         $BCD
054D:1  Connection_Type                     0=Cable, 3=lost, F=Wireless
054F:1  Countdown_time_to_next_datBinary    $HEX / 2.0
05D8:4  Absolute_Pressure                   $BCD / 10.0
05E2:4  Relative_Pressure                   $BCD / 10.0
05EC:4  Pressure_Correction                 $BCD / 10.0- 1000
05F6:4  Min_Absolute_Pressure               $BCD / 10.0
0600:4  Min_Relative_Pressure               $BCD / 10.0
060A:4  Max_Absolute_Pressure               $BCD / 10.0
0614:4  Max_Relative_Pressure               $BCD / 10.0
061E:9  Min_Pressure_datetime               time_convert($BCD)
0628:9  Max_Pressure_datetime               time_convert($BCD)
063C:4  Low_Alarm_Pressure                  $BCD / 10.0
0650:4  High_Alarm_Pressure                 $BCD / 10.0
