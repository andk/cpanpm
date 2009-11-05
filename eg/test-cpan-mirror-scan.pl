#!/usr/bin/env perl
use strict;
use warnings;
use CPAN::Mirrors;
my $cm = CPAN::Mirrors->new( "MIRRORED.BY" );
$|++;
my @best = $cm->best_mirrors( 
  how_many => 5, verbose => 1, callback => sub { print "." } 
);
print "Results:\n";
print "  " . $_->url . "\n" for @best;

