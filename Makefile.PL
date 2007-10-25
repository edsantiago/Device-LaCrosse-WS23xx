# $Id: Makefile.PL,v 1.2 2002/02/19 21:03:52 esm Exp $
use ExtUtils::MakeMaker;

WriteMakefile(
	      LIBS         => '',
	      INC          => '',
	      NAME         => 'Device::LaCrosse::WS23xx',
	      PMLIBDIRS    => [ '' ],
	      VERSION_FROM => 'WS23xx.pm',
);
