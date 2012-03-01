use strict;
use ExtUtils::MakeMaker;
eval { require File::Spec; };
my $HAVE_FILE_SPEC = !$@;

my $version_diff = 0; # we'll have to die if this becomes true
my $version_from;
if ($HAVE_FILE_SPEC) {
  $version_from = File::Spec->catfile(qw(CPAN.pm));
  my $version_set_manually = 1; # not by SVN

  if ($ARGV[0] && $ARGV[0] eq "--setversion") {
    die "Your perl is a bit dated[$]].\nDo not make a release with it\n" if $] < 5.008;
    {
      local $^W;
      die "Your MakeMaker is a bit dated[$ExtUtils::MakeMaker::VERSION].\nDo not make a release with it\n"
          if $ExtUtils::MakeMaker::VERSION+0 < 6.30;
    }
    die "Your MakeMaker doesn't do the sign woodoo" unless
        MM->can("signature_target");
    shift @ARGV;
    my $st;
    $ENV{LANG} = "C";
    my $dirty = ! system "git status -a > /dev/null";
    die "Not everything checked in or out?" if $dirty;

    if ($version_set_manually) {
      # we must control that the VERSION in CPAN.pm is the same as in the Makefile
      unshift @INC, ".";
      require $version_from;
      open my $fh, "make the-release-name|" or die;
      my $have_version;
      while (<$fh>) {
        next unless /^version\s+([\d\._]+)/;
        $have_version = eval $1;
      }
      die "could not determine current version from Makefile" unless $have_version;
      eval q{
      no warnings "numeric";
      if ($Bundle::CPAN::VERSION != $have_version) {
        warn sprintf "Not equal: Bundle::CPAN::VERSION[%s] ".
             "Makefile version[%s] <=>[%s]",
$Bundle::CPAN::VERSION,
$have_version,
$Bundle::CPAN::VERSION <=> $have_version,
;
        $version_diff = 1;
      }
};
      die $@ if $@;
    }
    exit unless $version_diff;
  }
}

my @sign = (MM->can("signature_target") ? (SIGN => 1) : ());
WriteMakefile(
              NAME          => 'Bundle::CPAN',
              VERSION_FROM  => 'CPAN.pm',
              LICENSE       => 'perl',
              AUTHOR        => 'Andreas Koenig',
              ABSTRACT      => 'Bundle to optimize the behaviour of CPAN.pm',
              @sign,
              dist => {
                       DIST_DEFAULT => join(" ",
                                            "verify-changes-date",
                                            "verify-changes-version",
                                            "Makefile",
                                            "setversion",
                                            "all",
                                            "tardist",
                                       ),
                       COMPRESS => 'gzip -9f'
                      },
              ($ExtUtils::MakeMaker::VERSION >= 6.4502 ?
               (META_ADD => {
                             resources => {
                                 repository => "git://github.com/andk/cpanpm.git",
                                 homepage   => "https://github.com/andk/cpanpm/tree/master/related/Bundle-CPAN"
                             },
                             keywords => ['CPAN','module','module installation'],
                            }) : ()),
);

if ($version_diff){
  die "
==> I had to update some \$VERSIONs <==
==> Your Makefile has been rebuilt. <==
==> Please rerun the make command.  <==
";
}

package MY;

sub makefile {
  my $self = shift;
  my $result = $self->SUPER::makefile(@_);
  $result =~ s/ : / :: /;
  $result;
}

sub postamble {
  q{
Makefile :: CPAN.pm

setversion:
	$(PERL) Makefile.PL --setversion

the-release-name :
	$(NOECHO) $(ECHO) 'version ' $(VERSION)
	$(NOECHO) $(ECHO) 'release-name ' $(DISTVNAME).tar$(SUFFIX)


diff::
	svn diff | less

howto-release:
	@$(ECHO) make ci dist \&\& make release

verify-changes-date:
	@$(PERL) -ne 'BEGIN{my@t=(localtime)[5,4,3];$$t[0]+=1900;$$t[1]++;$$t=sprintf"%04d-%02d-%02d",@t}' \
		-e '$$ok++,exit if /^$$t\s/; END{die "Alert: did not find <$$t> in Changes file" unless $$ok}' Changes

verify-changes-version:
	@$(PERL) -ne '$$ok++,exit if /\b$(VERSION)\b/; END{die "Alert: did not find <$(VERSION)> in Changes file" unless $$ok}' Changes

}
}

sub dist_ci {
  return qq{ci :
	svn ci
};
}

sub dist_test {
  return q{
# if we depend on $(DISTVNAME).tar$(SUFFIX), then the rest of the
# Makefile breaks our intent to NOT remake dist
disttest :
	rm -rf $(DISTVNAME)
	tar xvzf $(DISTVNAME).tar$(SUFFIX)
	cd $(DISTVNAME) && $(ABSPERLRUN) Makefile.PL
	cd $(DISTVNAME) && $(MAKE) $(PASTHRU)
	cd $(DISTVNAME) && $(MAKE) test $(PASTHRU)

distdir ::
	$(CP) $(DISTVNAME)/SIGNATURE ./SIGNATURE
	$(CP) $(DISTVNAME)/META.yml  ./META.yml
	$(CP) $(DISTVNAME)/MANIFEST  ./MANIFEST

}
}

sub distdir {
  my $self = shift;
  my $out = $self->SUPER::distdir;
  $out =~ s/distdir :/distdir ::/g;
  return $out;
}

# dist_dir was the name in very old MakeMaker as of 5.005_04
sub dist_dir {
  my $self = shift;
  my $out = $self->SUPER::dist_dir;
  $out =~ s/distdir :/distdir ::/g;
  return $out;
}
