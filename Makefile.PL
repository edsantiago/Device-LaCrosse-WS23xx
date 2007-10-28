use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Device::LaCrosse::WS23xx',
    AUTHOR        => 'Eduardo Santiago <esm@cpan.org>',
    VERSION_FROM  => 'lib/Device/LaCrosse/WS23xx.pm',
    ABSTRACT_FROM => 'lib/Device/LaCrosse/WS23xx.pm',
    PREREQ_PM     => { 'Test::More' => 0 },
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean         => { FILES => 'Device-LaCrosse-WS23xx-*' },
);

#
# FIXME
#
sub MY::postamble {
    return <<'MAKE_FRAG';
newmappings:	memory_map_2300.txt memory_map_2300.pl
	@echo "FIXME: trim DATA from WS23xx.pm"
	./memory_map_2300.pl >> WS23xx.pm
MAKE_FRAG
}
