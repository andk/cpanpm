#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet

use ExtUtils::MakeMaker qw(:DEFAULT);
use CPAN::FirstTime;
use File::Path;
use strict;

# $Id: Makefile.PL,v 1.48 2003/04/08 13:49:56 k Exp $

my $prereq_pm = { 'File::Spec' => 0.8 }; # probably not needed anymore

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
