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
000F:1  Wind_unit                                0=m/s, 1=knots, 2=beaufort, 3=km/h, 4=mph
0266:1  LCD_contrast                             $BCD+1 (Read Only: changing it has no impact on LCD.)
026B:1  Forecast                                 0=Rainy, 1=Cloudy, 2=Sunny
026C:1  Tendency                                 0=Steady, 1=Rising, 2=Falling
0346:4  Indoor_Temperature [C]                   $BCD / 100.0 - 30
034B:4  Min_Indoor_Temperature [C]               $BCD / 100.0 - 30
0350:4  Max_Indoor_Temperature [C]               $BCD / 100.0 - 30
0354:10 Min_Indoor_Temperature_datetime [s]      time_convert($BCD)
035E:10 Max_Indoor_Temperature_datetime [s]      time_convert($BCD)
0369:4  Low_Alarm_Indoor_Temperature [C]         $BCD / 100.0 - 30
036E:4  High_Alarm_Indoor_Temperature [C]        $BCD / 100.0 - 30
0373:4  Outdoor_Temperature [C]                  $BCD / 100.0 - 30
0378:4  Min_Outdoor_Temperature [C]              $BCD / 100.0 - 30
037D:4  Max_Outdoor_Temperature [C]              $BCD / 100.0 - 30
0381:10 Min_Outdoor_Temperature_datetime [s]     time_convert($BCD)
038B:10 Max_Outdoor_Temperature_datetime [s]     time_convert($BCD)
0396:4  Low_Alarm_Outdoor_Temperature [C]        $BCD / 100.0 - 30
039B:4  High_Alarm_Outdoor_Temperature [C]       $BCD / 100.0 - 30
03A0:4  Windchill [C]                            $BCD / 100.0 - 30
03A5:4  Min_Windchill [C]                        $BCD / 100.0 - 30
03AA:4  Max_Windchill [C]                        $BCD / 100.0 - 30
03AE:10 Min_Windchill_datetime [time_t]          yymmddhhmm($BCD)
03B8:10 Max_Windchill_datetime [time_t]          yymmddhhmm($BCD)
03C3:4  Low_Alarm_Windchill [C]                  $BCD / 100.0 - 30
03C8:4  High_Alarm_Windchill [C]                 $BCD / 100.0 - 30
03CE:4  Dewpoint [C]                             $BCD / 100.0 - 30
03D3:4  Min_Dewpoint [C]                         $BCD / 100.0 - 30
03D8:4  Max_Dewpoint [C]                         $BCD / 100.0 - 30
03DC:10 Min_Dewpoint_datetime [s]                time_convert($BCD)
03E6:10 Max_Dewpoint_datetime [s]                time_convert($BCD)
03F1:4  Low_Alarm_Dewpoint [C]                   $BCD / 100.0 - 30
03F6:4  High_Alarm_Dewpoint [C]                  $BCD / 100.0 - 30
03FB:2  Indoor_Humidity [%]                      $BCD
03FD:2  Min_Indoor_Humidity [%]                  $BCD
03FF:2  Max_Indoor_Humidity [%]                  $BCD
0401:10 Min_Indoor_Humidity_datetime [s]         time_convert($BCD)
040B:10 Max_Indoor_Humidity_datetime [s]         time_convert($BCD)
0415:2  Low_Alarm_Indoor_Humidity [%]            $BCD
0417:2  High_Alarm_Indoor_Humidity [%]           $BCD
0419:2  Outdoor_Humidity [%]                     $BCD
041B:2  Min_Outdoor_Humidity [%]                 $BCD
041D:2  Max_Outdoor_Humidity [%]                 $BCD
041F:10 Min_Outdoor_Humidity_datetime [s]        time_convert($BCD)
0429:10 Max_Outdoor_Humidity_datetime [s]        time_convert($BCD)
0433:2  Low_Alarm_Outdoor_Humidity [%]           $BCD
0435:2  High_Alarm_Outdoor_Humidity [%]          $BCD
054D:1  Connection_Type                          0=Cable, 3=lost, F=Wireless
054F:2  Countdown_time_to_next_datBinary [s]     $HEX / 2.0
05D8:5  Absolute_Pressure [hPa]                  $BCD / 10.0
05E2:5  Relative_Pressure [hPa]                  $BCD / 10.0
05EC:5  Pressure_Correction [hPa]                $BCD / 10.0- 1000
05F6:5  Min_Absolute_Pressure [hPa]              $BCD / 10.0
0600:5  Min_Relative_Pressure [hPa]              $BCD / 10.0
060A:5  Max_Absolute_Pressure [hPa]              $BCD / 10.0
0614:5  Max_Relative_Pressure [hPa]              $BCD / 10.0
061E:10 Min_Pressure_datetime [s]                time_convert($BCD)
0628:10 Max_Pressure_datetime [s]                time_convert($BCD)
063C:5  Low_Alarm_Pressure [hPa]                 $BCD / 10.0
0650:5  High_Alarm_Pressure [hPa]                $BCD / 10.0
