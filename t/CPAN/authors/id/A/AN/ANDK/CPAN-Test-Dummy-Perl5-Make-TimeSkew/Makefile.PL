use strict;
use ExtUtils::MakeMaker;
use File::Spec;
sub _f ($) {File::Spec->catfile(split /\//, shift);}

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make::TimeSkew',
              VERSION_FROM  => _f('./lib/CPAN/Test/Dummy/Perl5/Make/TimeSkew.pm'),
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              ($ExtUtils::MakeMaker::VERSION >= 6.31 ?
               (LICENSE      => "perl") : (),
              ),
              PL_FILES      => {},
              dist => {
                       DIST_DEFAULT => (
                                        'tamper-timestamps-now Makefile verify-MakeMaker-6.31 verify-no-subdir all tamper-timestamps-eot tardist'
                                       ),
                      },
);

package MY;

sub MY::dist_core {
    my $self = shift;
    my @m = $self->SUPER::dist_core(@_);
    my $m = join "", @m;
    # die "DEBUG: $m\n\n\n";
    $m =~ s/^tardist\s*:/tardist::/m;
    return $m;
}

sub MY::postamble {
  return q{
verify-MakeMaker-6.31:
	@$(PERL) -MExtUtils::MakeMaker -e 'my $$v = eval $$ExtUtils::MakeMaker::VERSION; die "Your MM is old, do not use it for a distro" unless $$v >= 6.31'

verify-no-subdir:
	@$(PERL) -e 'my$$s=join",",grep{!/^(lib|t)\z/&&-d($$_)}glob"*";die"unexpected dir:$$s"if$$s'

tamper-timestamps-now:
	@$(PERL) -e 'utime((time)x2,"Makefile.PL") or die'

tardist:: tamper-timestamps-eot

tamper-timestamps-eot:
	@$(PERL) -e 'utime 2147483647, 2147483647, "Makefile.PL" or die'

}


}
