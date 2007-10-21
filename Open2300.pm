# -*- perl -*-
#
# Open2300 - interface to La Crosse WS-23xx weather stations
#
# $Id: NIS.pm,v 1.10 2003/03/19 12:32:07 esm Exp $
#
package Open2300;

use strict;
# use warnings;			# Sigh, only available in 5.6 and above
use Carp;

###############################################################################
# BEGIN user-customizable section


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

sub TIEARRAY {
    my $class = shift;
    my $ws    = shift;		# in: weatherstation object

}

###############################################################################

1;

__END__
