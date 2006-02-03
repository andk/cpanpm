use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make',
              VERSION       => '1.01',
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              'dist' => {
                         DIST_DEFAULT => 'Makefile README all tardist',
                        },
              PL_FILES      => {},
);


sub postamble {
  q{
README: lib/CPAN/Test/Dummy/Perl5/Make.pm
	-[ -r $@ ] && chmod +w $@
	-$(PERL) -MPod::Text -e 'Pod::Text->new->parse_from_file(\*ARGV)' lib/CPAN/Test/Dummy/Perl5/Make.pm > $@
};
}
