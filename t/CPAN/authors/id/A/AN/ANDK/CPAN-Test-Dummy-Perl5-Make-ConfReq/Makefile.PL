eval q{
use CPAN::Test::Dummy::Perl5::Make 1.05; # configure_requires must take care for this
};

if ($@ && $ARGV[0] ne "open_the_backdoor") {
  die $@;
}
use strict;
use ExtUtils::MakeMaker;
use File::Spec;
sub _f ($) {File::Spec->catfile(split /\//, shift);}

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make::ConfReq',
              VERSION_FROM  => _f('./lib/CPAN/Test/Dummy/Perl5/Make/ConfReq.pm'),
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              ($ExtUtils::MakeMaker::VERSION >= 6.31 ?
               (LICENSE      => "perl") : (),
              ),
              'dist' => {
                         DIST_DEFAULT => 'Makefile all tardist',
                        },
              PL_FILES      => {},
              dist => {
                       DIST_DEFAULT => (
                                        'Makefile META.yml verify-MakeMaker-6.31 verify-no-subdir all tardist'
                                       ),
                      },
);

sub MY::postamble {
  return q{
verify-MakeMaker-6.31:
	@$(PERL) -MExtUtils::MakeMaker -e 'my $$v = eval $$ExtUtils::MakeMaker::VERSION; die "Your MM is old[$$v], do not use it for a distro" unless $$v >= 6.31'

verify-no-subdir:
	@$(PERL) -e 'my$$s=join",",grep{!/^(lib|t)\z/&&-d($$_)}glob"*";die"unexpected dir:$$s"if$$s'

META.yml: metafile
	$(CP) ./mymeta.yml $(DISTVNAME)/META.yml
}
}
