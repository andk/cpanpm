#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use lib "lib";
use CPAN::MakeMaker qw(:DEFAULT);
use CPAN::FirstTime;
use File::Path;
use strict;

# $Id: Makefile.PL,v 1.45 2003/02/08 17:06:51 k Exp $

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $prereq_pm = { 'File::Spec' => 0 };

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
  q{README: lib/CPAN.pm Makefile
	chmod +w $@
	pod2text lib/CPAN.pm > $@
}
}
