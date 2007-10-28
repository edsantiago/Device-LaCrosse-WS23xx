# -*- perl -*-
#
# Device::LaCrosse::WS23xx - interface to La Crosse WS-23xx weather stations
#
# $Id: NIS.pm,v 1.10 2003/03/19 12:32:07 esm Exp $
#
package Device::LaCrosse::WS23xx;

use strict;
use warnings;
use Carp;
use Time::Local;

(our $ME = $0) =~ s|^.*/||;

###############################################################################
# BEGIN user-customizable section

our $Canonical = <<'END_CANONICAL';
Max		Maximum | Maximal
Min		Minimum | Minimal

Indoor		Indoors  | Inside  | In
Outdoor		Outdoors | Outside | Out

Pressure	Press | Air Pressure
Temperature	Temp
Humidity	Hum   | Relative Humidity | Rel Humidity
Windchill	Wind Chill
Wind_Speed	Wind Speed | Windspeed
Dewpoint	Dew Point
Rain		Rainfall  | Rain
END_CANONICAL

# The conversions we know how to do.  Format of this table is:
#
#    <from>    <to>(<precision>)   <expression>
#
# where:
#
#    from        name of units to convert FROM.  This must be one of the
#                units used in the DATA table at the bottom of this file.
#
#    to          name of units to convert TO.  Feel free to add your own.
#                Say, m/s to furlongs/fortnight or even degrees to radians.
#
#    precision   how many significant digits to return
#
#    expression  mathematical expression using the variable '$value'
#
our $Conversions = <<'END_CONVERSIONS';
C	F(1)		$value * 9.0 / 5.0 + 32

hPa	inHg(2)		$value / 33.8638864
hPa	mmHg(1)		$value / 1.3332239

m/s	kph(1)		$value * 3.6
m/s	kt(1)		$value * 1.9438445
m/s	mph(1)		$value * 2.2369363

mm	in(2)		$value / 25.4
END_CONVERSIONS

# END   user-customizable section
###############################################################################

require Exporter;
require DynaLoader;

use vars qw(@ISA %EXPORT_TAGS @EXPORT_OK @EXPORT);

@ISA = qw(Exporter DynaLoader);

%EXPORT_TAGS = ( );
@EXPORT_OK   = ( );
@EXPORT      = ( );

our $VERSION = '0.01';

our $PKG = __PACKAGE__;		# For interpolating into error messages

bootstrap Device::LaCrosse::WS23xx $VERSION;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $device = shift                     # in: mandatory arg
      or croak "Usage: ".__PACKAGE__."->new( \"/dev/LACROSS-DEV-NAME\" )";

    # Is $device path a plain (not device) file with a special name?
    if ($device =~ /map.*\.txt/  &&  ! -c $device) {
	return Device::LaCrosse::WS23xx::Fake->new($device, @_);
    }

    # FIXME: call xs code
    my $fh = open_2300($device)
	or die "cannot open\n";

    return bless {
		  path => $device,
		  fh   => $fh,
		 }, $class;
}


sub read_data {
    my $self    = shift;
    my $address = shift;
    my $length  = shift;

    # FIXME: enable caching of @_ ?
    return read_2300($self->{fh}, $address, $length);
}

sub get {
    my $self  = shift;
    my $field = shift
      or croak "Usage: $PKG->new( FIELD )";

    # First time through?  Read and parse the memory map at the
    # end of this file.
    $self->{fields} ||= do {
	my %fields;
	for my $line (<DATA>) {
	    next if $line =~ m!^\s*$!;		# Skip blank lines
	    next if $line =~ m!^\s*#!;		# Skip comments

	    $line =~ /^(\S+):(\S+)\s+(\S+)(\s+\[(.*?)\])?\s+(\S.*\S)/
	      or die "Internal error: Cannot grok '$line'";
	    $fields{lc $3} = {
		address => hex($1),
		count   => $2,
		name  => $3,
		units => $5 || '?',
		expr  => $6,
	    };
	}
	close DATA;

	\%fields;
    };

    # Canonicalize the requested field name, e.g.
    # 'Indoor Temp Max' => Max_Indoor_Temperature
    my $canonical_field = canonical_name($field);
    if (! exists $self->{fields}->{lc $canonical_field}) {
	(my $re = lc $field) =~ s/[ _]+/.*/g;
	my @match = grep { /$re/i } keys %{$self->{fields}};
	if (@match == 1) {
	    $canonical_field = $match[0];
	}
    }

    # Get the field info.
    # FIXME: If there's no such field, return undef instead of croaking?
    my $get = $self->{fields}->{lc $canonical_field}
      or croak "$ME: No such value, '$field'";

    my @data = $self->read_data($get->{address}, $get->{count});

    # Convert to string context: (0, 3, 0xF, 9) becomes '03F9'.
    my $data = join('', map { sprintf "%X",$_ } @data);

    # Asked for raw data?  If called with 'raw' as second argument,
    # return the nybbles directly as they are.
    if (@_ && lc($_[0]) eq 'raw') {
	return wantarray ? @data
	                 : $data;
    }

    # Interpret.  This will be done inside an eval which may access
    # two variables: $BCD and $HEX.  Both actually consist of the
    # same thing, they're just interpreted differently.  They are
    # the decimal or hexadecimal interpretation of the sequence
    # of data nybbles read from the device.  Note that data nybbles
    # are returned Least Significant First.  So if @data = (0, 3, 2)
    # then $BCD will be '230' (two hundred and thirty)
    # and  $HEX will be 0x230 (= decimal 560).
    my $BCD = reverse($data);
    $BCD =~ s/^0+//;
    $BCD = '0' if $BCD eq '';

    # Only evaluate $HEX if it is used in the expression.  That
    # prevents this warning: 'Integer overflow in hexadecimal number'
    # on the YYMMDDhhmm fields.
    my $HEX;
    my $expr = $get->{expr};
    if ($expr =~ /HEX/) {
	$HEX = hex($BCD);
    }

    # Special case for datetime: return a unix time_t
    sub time_convert($) {
	#             YY      MM     DD    hh    mm
	$_[0] =~ m!^(\d{1,2})(\d\d)(\d\d)(\d\d)(\d\d)$!
	  or die "$ME: Internal error: bad datetime '$_[0]'";
	return timelocal( 0,$5,$4, $3, $2-1, $1+100);
    }

    # Special case for values with well-defined meanings:
    #    0=Foo, 1=Bar, 2=Fubar, ...
    if ($expr =~ /\d=.*,.*\d=/) {
	my @string_value;
	for my $pair (split(/\s*,\s*/, $expr)) {
	    # FIXME: don't die!  This is customer code.
	    $pair =~ /([0-9a-f])=(.*)/i or die;
	    $string_value[hex($1)] = $2;
	}

	my $val = $string_value[hex($BCD)];
	if (defined $val) {
	    return $val;
	}
	else {
	    return "undefined($BCD)";
	}
    }

    # Interpret the equation, e.g. $BCD / 10.0
    my $val = eval($expr);
    if ($@) {
	croak "$ME: eval( $get->{expr} ) died: $@";
    }

    # Asked to convert units?
    if (@_) {
	return unit_convert($val, $get->{units}, $_[0]);
    }

    return $val;
}


sub unit_convert {
    my $value     = shift;
    my $units_in  = shift;
    my $units_out = shift;

    # Identity?
    if (lc($units_in) eq lc($units_out)) {
	return $value;
    }

    our %Convert;
    # First time through?  Read and parse the conversion table at top
    if (! keys %Convert) {
	for my $line (split "\n", $Conversions) {
	    next if $line eq '';
	    $line =~ m!^(\S+)\s+(\S+)\((\d+)\)\s+(.*)!
	      or croak "Internal error: Cannot grok conversion '$line'";
	    push @{ $Convert{$1} }, { to => $2, precision => $3, expr => $4 };
	}
    }

    # No known conversions for this unit?
    if (! exists $Convert{$units_in}) {
	warn "$ME: Cannot convert '$units_in' to anything\n";
	return $value;
    }
    my @conversions = @{ $Convert{$units_in} };

    # There exists at least one conversion.  Do we have the one
    # requested by our caller?
    my @match = grep { lc($_->{to}) eq lc($units_out) } @conversions;
    if (! @match) {
	my @try = map { $_->{to} } @conversions;
	my $try = join ", ", @try;
	warn "$ME: Cannot convert '$units_in' to '$units_out'.  Try: $try\n";
	return $value;
    }

    my $newval = eval $match[0]->{expr};
    if ($@) {
	warn "$@";
	return $value;
    }

    return sprintf("%.*f", $match[0]->{precision}, $newval);
}


###############################################################################
# BEGIN canonical_name

################
#
# canonical_name
#
sub canonical_name {
    my $desc = shift;
    my $canonical_name = '';

    $desc =~ s/_/ /g;

    # Min or Max?
    if ($desc =~ s/\bmin(imum)?\b/ /i) {
	$canonical_name .= 'Min_';
    }
    elsif ($desc =~ s/\bmax(imum)?\b/ /i) {
	$canonical_name .= 'Max_';
    }
    elsif ($desc =~ s/\b(High|Low)\s*Alarm\b/ /i) {
	$canonical_name .= ucfirst(lc($1)) . '_Alarm_';
    }
    elsif ($desc =~ s/\bCurrent\b/ /i) {
	# do nothing
    }

    # Where?
    if ($desc =~ s/\b(in|out)(doors?)?(\b|$)/ /i) {
	$canonical_name .= ucfirst(lc($1) . 'door') . '_';
    }

    # What: Temperature, Windchill, Pressure, ...
    if ($desc =~ s/\btemp(erature)?\b/ /i) {
	$canonical_name .= 'Temperature';
    }
    elsif ($desc =~ s/\bPress(ure)?\b/ /i) {
	$desc =~ s/\bair\b/ /i;

	if ($desc =~ s/\bAbs(olute)?\b/ /i) {
	    $canonical_name .= 'Absolute_';
	}
	elsif ($desc =~ s/\bRel(ative)?\b/ /i) {
	    $canonical_name .= 'Relative_';
	}
	$canonical_name .= 'Pressure';
	if ($desc =~ s/\bCorrection\b/ /i) {
	    $canonical_name .= '_Correction';
	}
    }
    elsif ($desc =~ s/\b(Humidity|Windchill|Dewpoint)\b/ /i) {
	$canonical_name .= ucfirst(lc($1));
	$desc =~ s/\bRel(ative)?\b/ /i;
    }
    elsif ($desc =~ s/\b(Rain)\b//i) {
	$canonical_name .= "Rain";
	if ($desc =~ s/\b(1|24)(\s*h(ou)?r?)?\b//i) {
	    $canonical_name .= "_$1hour";
	}
	elsif ($desc =~ s/\btotal\b//i) {
	    $canonical_name .= "_Total";
	}
    }
    else {
	(my $tmp = $desc) =~ s/\s+/_/g;
	$canonical_name .= $tmp;
	# FIXME: warn?
    }

    # Is this a date/time field?
    if ($desc =~ s!\bDate/Time\b! !i) {
	$canonical_name .= '_datetime';
    }

    if ($desc =~ /\S/) {
#	warn "leftover: $desc\n";
    }

    $canonical_name =~ s/_$//;

    return $canonical_name;
}

# END   canonical_name
###############################################################################
# BEGIN tie() code for treating the ws23xx as a perl array

sub TIEARRAY {
    my $class = shift;
    my $ws    = shift;		# in: weatherstation object _or_ path

    my $ws_obj;
    if (ref($ws)) {
	if (ref($ws) eq $PKG) {
	    $ws_obj = $ws;
	}
	else {
	    croak "Usage: tie \@X, $PKG, [ WS obj | /dev/path ]";
	}
    }
    else {
	$ws_obj = $class->new($ws)
	  or die "Cannot make a WS object out of $ws";
    }

    my $self = { ws => $ws_obj };

    return bless $self, $class;
}

sub FETCH {
    my $self  = shift;
    my $index = shift;

    # FIXME: assert that 0 <= index <= MAX
    # FIXME: read and cache more than just 1
    my @data = read_2300($self->{ws}->{fh}, $index, 1);

    return $data[0];
}

sub FETCHSIZE {
    return 0x13D0;
}

sub STORE {
    croak "Cannot (yet) write to WS23xx";
}

# END   tie() code for treating the ws23xx as a perl array
###############################################################################
# BEGIN fake-device handler for testing

package Device::LaCrosse::WS23xx::Fake;

use Carp;

our @ISA = qw(Device::LaCrosse::WS23xx);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $path = shift
      or croak "Usage: ".__PACKAGE__."->new( \"path_to_mem_map.txt\" )";

    my $self = {
        path     => $path,
	fakedata => [],
    };

    open my $map_fh, '<', $path
      or croak "Cannot read $path: $!";
    while (my $line = <$map_fh>) {
	# E.g. 0019 0   alarm set flags
	if ($line =~ m!^([0-9a-f]{4})\s+([0-9a-f])\s*!i) {
	    $self->{fakedata}->[hex($1)] = hex($2);
	}
    }
    close $map_fh;

    return bless $self, $class;
}

sub read_data {
    my $self    = shift;
    my $address = shift;
    my $length  = shift;

    return @{$self->{fakedata}}[$address .. $address+$length-1];
}

# END   fake-device handler for testing
###############################################################################

# Need to reset package, so we can read <DATA>
package Device::LaCrosse::WS23xx;

###############################################################################
# BEGIN documentation

=head1  NAME

Device::LaCrosse::WS23xx - read data from La Crosse weather station

=head1  SYNOPSIS

  use Device::LaCrosse::WS23xx;

  my $ws = Device::LaCrosse::WS23xx->new("/dev/lacrosse")
      or die "Cannot FIXME FIXME";

  for my $field qw(Indoor_Temp Pressure_Rel Outdoor_Humidity) {
      printf "%-15s = %s\n", $field, $ws->get($field);
  }


=head1  DESCRIPTION

=head1  CONSTRUCTOR

=over 4

=item B<new>( PATH )

Establishes a connection to the weather station.
PATH is the serial line hooked up to the weather station.  Typical
values are C</dev/ttyS0>, C</dev/ttyUSB0>.

=back

=head1  METHODS

=over 4

=item   B<get>( FIELD [, CONVERT] )

Retrieves data from the weather station, and FIXME FIXME


=item   B<method2>

...

=back

=head1  AUTHOR

Ed Santiago <esm@cpan.org>

=cut

# END   documentation
###############################################################################

1;

__DATA__
000F:1  Wind_unit                                0=m/s, 1=knots, 2=beaufort, 3=km/h, 4=mph
0266:1  LCD_contrast                             $BCD+1
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
03AE:10 Min_Windchill_datetime [s]               time_convert($BCD)
03B8:10 Max_Windchill_datetime [s]               time_convert($BCD)
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
0497:6  Rain_24hour [mm]                         $BCD / 100.0
049D:6  Max_Rain_24hour [mm]                     $BCD / 100.0
04A3:10 Max_Rain_24hour_datetime [s]             time_convert($BCD)
04B4:6  Rain_1hour [mm]                          $BCD / 100.0
04BA:6  Max_Rain_1hour [mm]                      $BCD / 100.0
04C0:10 Max_Rain_1hour_datetime [s]              time_convert($BCD)
04D2:6  Rain_Total [mm]                          $BCD / 100.0
04D8:10 Rain_Total_datetime [s]                  time_convert($BCD)
0529:3  Wind_Speed [m/s]                         $HEX / 10.0
052C:1  Wind_Direction [degrees]                 $HEX * 22.5
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
