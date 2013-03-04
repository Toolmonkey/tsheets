use 5.012004;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'tsheets',
    VERSION_FROM      => 'lib/tsheets.pm', 
    PREREQ_PM         => {
				'Moose'	                => 0,
				'JSON::XS'              => 0,
				'LWP::UserAgent'        => 0,
				'Data::Dumper'          => 0,
				'XML::Simple'           => 0,
				'LWP::Protocol::https'	=> 0,
	}, 
    ($] >= 5.012 ?     
      (ABSTRACT  		=> 'Unofficial Perl interface to the tsheets.com API',
       AUTHOR			=> 'Scott Cudney <tsheets-module-dev@cudneys.net>') : ()),
);
