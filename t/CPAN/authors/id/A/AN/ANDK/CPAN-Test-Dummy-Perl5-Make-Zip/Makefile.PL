use strict;
use ExtUtils::MakeMaker;
use File::Spec;
sub _f ($) {File::Spec->catfile(split /\//, shift);}

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make::Zip',
              VERSION_FROM  => _f('./lib/CPAN/Test/Dummy/Perl5/Make/Zip.pm'),
              ($ExtUtils::MakeMaker::VERSION >= 6.3002 ?
               (LICENSE      => "perl") : (),
              ),
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              'dist' => {
                         DIST_DEFAULT => 'Makefile all zipdist',
                        },
              PL_FILES      => {},
              PREREQ_PM     => {
                                CPAN::Test::Dummy::Perl5::Make => 0,
                               }
);
