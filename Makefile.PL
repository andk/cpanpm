#!/usr/bin/perl -w
use lib "lib";
use ExtUtils::MakeMaker qw(:DEFAULT neatvalue);
use CPAN::FirstTime;
use File::Path;
use strict;

# $Id: Makefile.PL,v 1.23 1996/12/10 10:13:30 k Exp $

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'CONFIGURE' => sub { &CPAN::FirstTime::init(MY->catfile(qw(lib CPAN Config.pm))) },
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
	/usr/local/bin/zcat \$? > \$\@
};
    return join "", @m;
}

