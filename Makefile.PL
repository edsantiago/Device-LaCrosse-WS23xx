# $Id: Makefile.PL,v 1.2 2002/02/19 21:03:52 esm Exp $
use ExtUtils::MakeMaker;

WriteMakefile(
	      LIBS         => '-lnsl',
	      INC          => '',
	      DISTNAME     => 'Net-NIS',
	      NAME         => 'Net::NIS',
	      PMLIBDIRS    => [ 'NIS' ],
	      VERSION_FROM => 'NIS.pm',
);
