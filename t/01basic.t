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

use Open2300;

$loaded = 1;

my $x = Open2300->new("/dev/lacrosse");

ok $x->{fh}, 3, "foo";

exit 0;
