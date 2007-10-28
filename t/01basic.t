# -*- perl -*-
#
#
use strict;
use Test::More;

my $loaded = 0;

BEGIN {
  plan tests => 3;
}
END { $loaded or print "not ok 1\n"; }

use Device::LaCrosse::WS23xx;

$loaded = 1;

my $ws = Device::LaCrosse::WS23xx->new("/dev/lacrosse");

is $ws->{fh}, 3, "Device filehandle number";

my @datetime = $ws->_read_data( 0x0200, 6 );

my @now = gmtime;

is scalar(@datetime), 6, "scalar(\@datetime)";

# Compare only the hour.  The WWV synchronization sucks on this
# thing, and it's off by 2 minutes.
is $datetime[5]*10 + $datetime[4], $now[2], "current hour";

exit 0;
