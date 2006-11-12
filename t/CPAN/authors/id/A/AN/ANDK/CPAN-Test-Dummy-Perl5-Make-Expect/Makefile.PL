use strict;
use ExtUtils::MakeMaker qw(prompt WriteMakefile);
use File::Spec;
sub _f ($) {File::Spec->catfile(split /\//, shift);}

if ($ENV{PERL_TEST_DUMMY_PERL5_MAKE_EXPECT}) {
  if ($ENV{PERL_TEST_DUMMY_PERL5_MAKE_EXPECT} eq "Oui, je suis Catherine Deneuve") {
    if ("@ARGV" eq "Belle de jour") {
      my %q = (
               "6*8" => "48",
               "3*2" => "6",
               "3*7" => "21",
               "Unicode Codepoint of Won, hexadecimal" => "20A9",
              );
      my @q = keys %q;
      my $q = scalar @q;
      print "I will ask you $q questions now\n";
      my $ok = 1;
      while (@q) {
        my $i = int rand scalar @q;
        my $q = $q[$i];
        my $a = delete $q{$q};
        my $but = prompt($q);
        if (lc $but eq lc $a) {
          print "Thank you\n";
        } else {
          warn "Wrong answer\n";
          $ok = 0;
        }
        @q = keys %q;
      }
      if ($ok) {
        open FH, ">ok.ts" or die;
        print FH scalar localtime, "\n";
        close FH;
      } else {
        unlink "ok.ts";
      }
    } else {
      warn "you are not 'Belle de jour'";
    }
  } else {
    warn "you are not Catherine Deneuve";
  }
} else {
  warn "incorrect env";
}

WriteMakefile(
              NAME          => 'CPAN::Test::Dummy::Perl5::Make::Expect',
              VERSION_FROM  => _f('./lib/CPAN/Test/Dummy/Perl5/Make/Expect.pm'),
              ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
              ($ExtUtils::MakeMaker::VERSION >= 6.31 ?
               (LICENSE      => "perl") : (),
              ),
              'dist' => {
                         DIST_DEFAULT => 'Makefile all tardist',
                        },
              clean => {
                        FILES => "ok.ts",
                       },
              PL_FILES      => {},
              dist => {
                       DIST_DEFAULT => (
                                        'Makefile verify-MakeMaker-6.31 verify-no-subdir all tardist'
                                       ),
                      },
);

sub MY::postamble {
  return q{
verify-MakeMaker-6.31:
	@$(PERL) -MExtUtils::MakeMaker -e 'my $$v = eval $$ExtUtils::MakeMaker::VERSION; die "Your MM is old, do not use it for a distro" unless $$v >= 6.31'

verify-no-subdir:
	@$(PERL) -e 'my$$s=join",",grep{!/^(lib|t)\z/&&-d($$_)}glob"*";die"unexpected dir:$$s"if$$s'
}
}
