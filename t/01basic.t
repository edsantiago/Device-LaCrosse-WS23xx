# -*- perl -*-
#
#
use strict;
use Test;

my $loaded = 0;

BEGIN {
  plan tests => 1;
}
END { $loaded or print "not ok 1\n"; }

use Device::LaCrosse::WS23xx;

$loaded = 1;

# my $x = Device::LaCrosse::WS23xx->new("/dev/lacrosse");

# ok $x->{fh}, 3, "foo";
ok 1, 1, "foo";

exit 0;
