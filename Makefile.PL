#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use ExtUtils::MakeMaker qw(:DEFAULT);
use File::Path;
use File::Spec;
use strict;

# $Id: Makefile.PL,v 1.53 2003/07/31 14:47:45 k Exp $

my $prereq_pm = { 'File::Spec' => 0, 'Test::More' => 0 };
if ($] < 5.006001){
  # 5.6.0 / 1.52 downloads 5.8.0 due to File::Spec
  $prereq_pm = { 'Test::More' => 0 };
}

WriteMakefile(
    'INSTALLDIRS' => 'perl',  # as it is coming with perl
    'NAME'	=> 'CPAN',
    'VERSION_FROM' => 'lib/CPAN.pm',
    'EXE_FILES' => [qw(scripts/cpan)],
    'clean' => { FILES => "lib/CPAN/Config.pm" },
    'PREREQ_PM' => $prereq_pm,
    'dist' => {
	       DIST_DEFAULT => 'README all checkout_meta metafile sign tardist checkin_meta',
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
README: lib/CPAN.pm Makefile
	chmod +w $@
	pod2text lib/CPAN.pm > $@

checkout_meta ::
	false && co -l META.yml

checkin_meta ::
	false && ci -u META.yml

sign ::
	cpansign -s

}
}

sub MY::dist_ci {
  return qq{ci :
	svn ci
};
}

