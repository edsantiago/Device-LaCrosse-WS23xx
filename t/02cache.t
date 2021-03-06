# -*- perl -*-
#
#
use strict;
use warnings;
use Test::More skip_all => "December 2010 : dead hardware";

use Device::LaCrosse::WS23xx;

plan tests => 2;

my $ws = Device::LaCrosse::WS23xx->new("/dev/lacrosse", cache_expire => 2)
  or do {
      diag "Cannot talk to /dev/lacrosse";
      exit 1;
  };

# Get the counter...
my $name = 'Countdown_time_to_next_datBinary';
my $countdown = $ws->get($name);

# ...and get it again after a second.
sleep 1;
my $countdown2 = $ws->get($name);

# They should be the same, because the cache hasn't expired.
is $countdown2, $countdown, "Cache read after 1 second gets stale data";

sleep 2;

$countdown2 = $ws->get($name);

isnt $countdown2, $countdown, "Cache read after 3 seconds gets new data";
