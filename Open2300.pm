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
Temp_Indoor	     degreesC	[0x346:4] / 100.0 - 30.0
Temp_Indoor_Min	     degreesC	[0x34B:4] / 100.0 - 30.0
Temp_Indoor_Max	     degreesC	[0x350:4] / 100.0 - 30.0

Temp_Indoor_Min_t    datetime	[0x354:10]
Temp_Indoor_Max_t    datetime	[0x35E:10]

Temp_Outdoor	     degreesC	[0x373:4] / 100.0 - 30.0
Temp_Outdoor_Min     degreesC	[0x378:4] / 100.0 - 30.0
Temp_Outdoor_Max     degreesC	[0x37D:4] / 100.0 - 30.0

Humidity_Indoor      percent	[0x03FB:2]
Humidity_Indoor_Min  percent	[0x03FD:2]
Humidity_Indoor_Max  percent	[0x03FF:2]

Humidity_Outdoor     percent	[0x0419:2]
Humidity_Outdoor_Min percent	[0x041B:2]
Humidity_Outdoor_Max percent	[0x041D:2]

Wind_Speed	     m/s	[0x0529:3]
Wind_Direction       degrees	[0x052C:1] * 22.5

Connection_Type	     string	[0x054D:1]

Countdown	     seconds	[0x054F:2] / 2.0

Pressure_Abs	     hPa	[0x05D8:5] / 10.0
Pressure_Rel	     hPa	[0x05E2:5] / 10.0
Pressure_Corr        hPa	[0x05EC:5] / 10.0

Rain_24h	     mm		[0x0497:6] / 100.0
Rain_1h		     mm		[0x04B4:6] / 100.0
Rain_Total           mm		[0x04D2:6] / 100.0
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
	for my $line (split "\n", $Values) {
	    next if $line =~ m!^\s*$!;		# Skip blank lines
	    $line =~ /^(\S+)\s+(\S+)\s+(\S.*\S)/
	      or die "Internal error: Cannot grok '$line'";
	    $fields{lc $1} = {
		name  => $1,
		key   => lc($1),
		units => $2,
		expr  => $3,
	    };
	}

	\%fields;
    };

    my $get = $self->{fields}->{lc $field}
      or croak "$ME: No such value, '$field'";

    my $expr = $get->{expr};

    $expr =~ s{^\[(0x[0-9a-f]+):(\d+)\]}
      {
	  my ($addr, $count) = (hex($1), $2);
	  my @foo = read_2300($self->{fh}, $addr, $count);

	  my $s = join('',reverse @foo);
	  $s =~ s/^0+//;
	  $s || '0';
      }gei;

    # Special case for datetime: return a unix time_t
    if ($get->{units} eq 'datetime') {
	#             YY      MM     DD    HH    MM
	$expr =~ m!^(\d{1,2})(\d\d)(\d\d)(\d\d)(\d\d)$!
	  or die "$ME: Internal error: bad datetime '$expr'";
	return timelocal( 0,$5,$4, $3, $2-1, $1+100);
    }

    my $val = eval($expr);
    if ($@) {
	croak "$ME: eval( $expr ) died: $@";
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

__END__
