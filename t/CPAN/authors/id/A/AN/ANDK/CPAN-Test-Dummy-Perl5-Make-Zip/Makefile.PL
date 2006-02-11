use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make::Zip',
              VERSION       => '1.01',
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              'dist' => {
                         DIST_DEFAULT => 'Makefile all zipdist',
                        },
              PL_FILES      => {},
);
