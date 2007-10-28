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
