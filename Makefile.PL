# $Id: Makefile.PL,v 1.2 2002/02/19 21:03:52 esm Exp $
use ExtUtils::MakeMaker;

WriteMakefile(
	      LIBS         => '',
	      INC          => '',
	      DISTNAME     => 'Open2300',
	      NAME         => 'Open2300',
	      PMLIBDIRS    => [ '' ],
	      VERSION_FROM => 'Open2300.pm',
);
