#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use ExtUtils::MakeMaker qw(:DEFAULT);
use File::Path;
use File::Spec;
use strict;

my $Id = q$Id: Makefile.PL 146 2005-08-09 04:25:21Z k $;
our $VERSION = sprintf "%.3f", 1 + substr(q$Rev: 146 $,4)/1000;

my $version_diff = 0; # we'll have to die if this becomes true
my $version_from = File::Spec->catfile(qw(lib CPAN.pm));

if ($ARGV[0] && $ARGV[0] eq "--setversion") {
  shift @ARGV;
  open my $st, "svn st -u|" or die;
  my $dirty = 0;
  while (<$st>) {
    next if /^\?/;
    next if /^Head revision:/;
    next if /^Status against revision:/;
    print;
    $dirty++;
  }
  close $st;
  die "Not everything checked in?" if $dirty;

  # $re parses the upper boundary of the output of svnversion
  my $re = qr/(?:\d+:)?(\d+)[SM]*$/;
  my($sv_dot)  = `svnversion .`             =~ $re;
  my($sv_from) = `svn st -u -v $version_from`  =~ /^.{8}\s*(?:\d+)\s*(\d+)/;
  die "Could not determine sv_from or sv_dot"
      unless $sv_from > 0 && $sv_dot > 0;
  if ($sv_dot > $sv_from) {
    warn "setting some property to make a checkin of this file possible";
    0==system(svn => "propset",
              "cpan:release",
              "after_$sv_dot",
              $version_from) or die;
    warn "checking in to get the version up to the bleading edge";
    0==system(svn => "ci",
              "-m",
              "Property set for release after_$sv_dot",
              $version_from) or die;
    # will have to die after Makefile is rewritten:
    $version_diff = 1;
  }
  exit unless $version_diff;
}

my $prereq_pm = { 'File::Spec' => 0, 'Test::More' => 0 };
if ($] < 5.006001){
  # 5.6.0 / 1.52 downloads 5.8.0 due to File::Spec
  $prereq_pm = { 'Test::More' => 0 };
}

# import PAUSE public key to user's keychain
require Config;
for my $dir (split /$Config::Config{path_sep}/, $ENV{PATH}) {
    my $abs = File::Spec->catfile($dir, 'gpg');
    if (my $cmd = MM->maybe_command($abs)) {
	print "Importing PAUSE public key into your GnuPG keychain... ";
	system($cmd, '--quiet', '--import', <PAUSE*.pub>);
	print "done!\n";
	print "(You may wish to trust it locally with 'gpg --lsign-key 450F89EC')\n";
	last;
    }
}

WriteMakefile(
              'INSTALLDIRS' => 'perl',  # as it is coming with perl
              'NAME'	=> 'CPAN',
              'VERSION_FROM' => 'lib/CPAN.pm',
              'EXE_FILES' => [qw(scripts/cpan)],
              'clean' => { FILES => "lib/CPAN/Config.pm" },
              'PREREQ_PM' => $prereq_pm,
              SIGN => 1,
              'dist' => {
                         DIST_DEFAULT => 'setversion README all tardist',
                         COMPRESS => 'gzip -9f'
                        },
);

# if we make sign first and make dist then, then any change to
# META.yml will ruin the signature

# if we make dist first and make sign then, then the correct signature
# will not be part of the tarball

# So we must alter make dist to first write META.yml, then let us
# sign, then do the tarball.

sub MY::postamble {
  q{
setversion:
	$(PERL) Makefile.PL --setversion

README: lib/CPAN.pm Makefile
	chmod +w $@
	pod2text lib/CPAN.pm > $@

sign ::
	cpansign -s && mv SIGNATURE $(DISTVNAME)/SIGNATURE

}
}

sub MY::dist_ci {
  return qq{ci :
	svn ci
};
}

