#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use lib "lib";
use ExtUtils::MakeMaker qw(:DEFAULT neatvalue);
use CPAN::FirstTime;
use File::Path;
use strict;

# $Id: Makefile.PL,v 1.38 2002/07/28 10:46:47 k Exp $

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $prereq_pm = { 'File::Spec' => 0, 'Test::More' => 0 };
if ($] < 5.006001){
  # 5.6.0 / 1.52 downloads 5.8.0 due to File::Spec
  $prereq_pm = { 'Test::More' => 0 };
}

WriteMakefile(
    'INSTALLDIRS' => 'perl',  # as it is coming with perl
    'NAME'	=> 'CPAN',
    'VERSION_FROM' => 'lib/CPAN.pm',
    'EXE_FILES' => [qw(cpan)],
    'clean' => { FILES => "lib/CPAN/Config.pm" },
    'PREREQ_PM' => $prereq_pm,
    'dist' => {
	       PREOP => 'pod2text lib/CPAN.pm > $(DISTVNAME)/README',
	       DIST_DEFAULT => 'all tardist',
	       COMPRESS => 'gzip -9f'
	      },
);

