# -*- perl -*-
#
#
use strict;
use Test::More;

my $loaded = 0;

BEGIN {
  plan tests => 2;
}
END { $loaded or print "not ok 1\n"; }

use Device::LaCrosse::WS23xx;

$loaded = 1;

my $x = Device::LaCrosse::WS23xx->new("memory_map_2300.txt");

is $x->get("LCD_Contrast"), 5, "LCD contrast";
is $x->get("Max_Dewpoint"), "8.44", "Max Dewpoint";
