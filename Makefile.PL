#!/usr/bin/perl -w
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use ExtUtils::MakeMaker qw(:DEFAULT);
use File::Path;
use File::Spec;
use strict;

# $Id: Makefile.PL,v 1.51 2003/07/28 08:17:51 k Exp $

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
	print "Importing PAUSE public key into your GnuPG keychain...\n";
	system($cmd, '--import', <PAUSE*.pub>);
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
