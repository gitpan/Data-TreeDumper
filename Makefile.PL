use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Data::TreeDumper',
    'VERSION_FROM'	=> 'TreeDumper.pm', # finds $VERSION
    'PREREQ_PM'		=> 
	    {
	    Term::Size  => 0.2,
	    Text::Wrap  => 2001.0929,
	    Devel::Size => 0.58, 
	    Class::ISA  => 0
	    },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'TreeDumper.pm', # retrieve abstract from module
       AUTHOR     => 'Khemir Nadim ibn Hamouda. <nadim@khemir.net>') : ()),
);
