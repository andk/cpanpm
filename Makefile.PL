#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use ExtUtils::MakeMaker qw(:DEFAULT);
use File::Path;
use strict;

# $Id: Makefile.PL,v 1.49 2003/04/12 03:37:02 k Exp $

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
	       DIST_DEFAULT => 'README all tardist',
	       COMPRESS => 'gzip -9f'
	      },
);

sub MY::postamble {
  q{
README: lib/CPAN.pm Makefile
	chmod +w $@
	pod2text lib/CPAN.pm > $@

}
}
