#!/usr/bin/perl -w
BEGIN {$CPAN::No_Config_is_ok=1}
BEGIN {$CPAN::No_Config_is_ok=1}
use lib "lib";
use ExtUtils::MakeMaker qw(:DEFAULT neatvalue);
use CPAN::FirstTime;
use File::Path;
use strict;

# $Id: Makefile.PL,v 1.25 1997/06/30 18:01:41 k Exp $

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'CONFIGURE' => sub {
	my($bad);
	eval {require CPAN::Config;};
	$bad++ if $@;
	eval {require CPAN::MyConfig;};
	$bad++ if $@;
	return if $bad<2;
	CPAN::FirstTime::init(MY->catfile(qw(lib CPAN Config.pm)));
    },
    'INSTALLDIRS' => 'perl',  # as it is coming with perl
    'NAME'	=> 'CPAN',
    'VERSION_FROM' => 'lib/CPAN.pm',
    'clean' => { FILES => "lib/CPAN/Config.pm" },
    'dist' => { 
	       PREOP => 'co -l README && pod2text lib/CPAN.pm > README && ci -u README',
	       DIST_DEFAULT => 'private all tardist',
	       COMPRESS => 'gzip -9f'
	      },
);

sub MY::postamble {
    my($self) = shift;
    my @m;
    push @m, qq{
# This is only for me (Andreas Koenig) for the distribution
private: MIRRORED.BY

MIRRORED.BY: /usr/sources/CPAN/MIRRORED.BY.gz
	gzip -dc \$? > \$\@
};
    return join "", @m;
}

