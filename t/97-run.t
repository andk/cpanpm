#!/usr/bin/perl

use strict;
use Test::More;
use File::Spec;

my $HAVE_PERLDOC = eval { require Pod::Perldoc; 1; };
unless ($HAVE_PERLDOC) {
    plan skip_all => "Test requires Pod::Perldoc to run";
}
plan tests => 32;

my $file = File::Spec->catfile('.', 'blib', 'script', 'cpan');

print "bail out! Script file is missing!" unless -e $file;
my $cmd = "$^X -Mblib $file -y 2>&1";
diag "will run '$cmd'";
my $output = `$cmd`;
like( $output, qr/Unknown option: y/, 'refuse unknown parameter' );

$ENV{CPANSCRIPT_LOGLEVEL} = 'TRACE';
$cmd = "$^X -Mblib $file -h 2>&1";
diag "will run '$cmd'";
$output = `$cmd`;
my($logger) = $output =~ /Using logger from (\S+)/;
ok $logger, "Found logger '$logger'";
for my $switch (qw(a A c C D f F g G h i I j J l m M n O P r s t T u v V w x X)) {
    like( $output, qr/^[ ]+-\Q$switch\E/m, "advertizing $switch" );
}
