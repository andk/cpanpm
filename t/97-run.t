#!/usr/bin/perl

use strict;
use Test::More qw(no_plan);
use File::Spec;

my $file = File::Spec->catfile('.', 'blib', 'script', 'cpan');

print "bail out! Script file is missing!" unless -e $file;
my $cmd = "$^X -Mblib $file -y 2>&1";
diag "will run '$cmd'";
my $output = `$cmd`;
like( $output, qr/Unknown option: y/, 'refuse unknown parameter' );

$cmd = "$^X -Mblib $file -h 2>&1";
diag "will run '$cmd'";
$output = `$cmd`;
for my $switch (qw(a A c C D f F g G h i I j J l m M n O P r s t T u v V w x X)) {
    like( $output, qr/^[ ]+-\Q$switch\E/m, "advertizing $switch" );
}

done_testing();
