use strict;
use ExtUtils::MakeMaker;
use File::Spec;
sub _f ($) {File::Spec->catfile(split /\//, shift);}

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make',
              VERSION_FROM  => _f'./lib/CPAN/Test/Dummy/Perl5/Make.pm',
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              ($ExtUtils::MakeMaker::VERSION >= 6.3002 ?
               (LICENSE      => "perl") : (),
              ),
              'dist' => {
                         DIST_DEFAULT => 'Makefile all tardist',
                        },
              PL_FILES      => {},
);
