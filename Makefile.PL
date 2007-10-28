# $Id: Makefile.PL,v 1.2 2002/02/19 21:03:52 esm Exp $
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Device::LaCrosse::WS23xx',
    VERSION_FROM => 'WS23xx.pm',

    ($] >= 5.005 ?  (ABSTRACT_FROM  => 'WS23xx.pm',
		     AUTHOR         => 'Eduardo Santiago <esm@cpan.org>')
	         :  ()
	     ),

    ($ExtUtils::MakeMaker::VERSION ge '6.30_00'?
	 ('LICENSE'         => 'perl', ) : ()),
);
