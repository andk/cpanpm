use strict;
use ExtUtils::MakeMaker;

die "This Makefile.PL of CPAN::Test::Dummy::Perl5::Make::Failearly
demonstrates what happens when a Makefile.PL dies.

This can be avoided by touching a file 'SURVIVE' in the current
directory.

Goodbye.
" unless -e "SURVIVE";
WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make::Failearly',
              VERSION       => '1.01',
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              PL_FILES      => {},
);
