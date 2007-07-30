use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::BuildOrMake',
              VERSION       => '1.01',
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              'dist' => {
                         DIST_DEFAULT => 'Makefile all tardist',
                        },
              PL_FILES      => {},
);
