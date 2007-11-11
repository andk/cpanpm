use strict;
use ExtUtils::MakeMaker qw(WriteMakefile);

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make::UnsatPrereq',
              VERSION       => '1.00',
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              ($ExtUtils::MakeMaker::VERSION >= 6.31 ?
               (LICENSE      => "perl") : (),
              ),
	      PREREQ_PM	    => { 'CPAN::Test::Dummy::Perl5::Make' => '99999999.99' },
);
