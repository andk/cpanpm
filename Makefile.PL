#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use lib "lib";
use ExtUtils::MakeMaker qw(:DEFAULT neatvalue);
use CPAN::FirstTime;
use File::Path;
use strict;

# $Id: Makefile.PL,v 1.35 2000/07/29 17:48:05 k Exp $

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'CONFIGURE' => sub {
	my($bad);
	eval {require CPAN::Config;};
	$bad++ if $@;
	push @INC, MY->catdir($ENV{HOME}, ".cpan");
	eval {require CPAN::MyConfig;};
	$bad++ if $@;
	return if $bad<2;
	CPAN::FirstTime::init(MY->catfile(qw(lib CPAN Config.pm)));
    },
    'INSTALLDIRS' => 'perl',  # as it is coming with perl
    'NAME'	=> 'CPAN',
    'VERSION_FROM' => 'lib/CPAN.pm',
    'EXE_FILES' => [qw(cpan)],
    'clean' => { FILES => "lib/CPAN/Config.pm" },
    'PREREQ_PM' => { 'File::Spec' => 0 },
    'dist' => {
	       PREOP => 'pod2text lib/CPAN.pm > $(DISTVNAME)/README',
	       DIST_DEFAULT => 'all tardist',
	       COMPRESS => 'gzip -9f'
	      },
);

