#!/usr/bin/env perl
use strict;
use warnings;
use CPAN::Mirrors;
my $how_many = shift || 5;
my $cm = CPAN::Mirrors->new( "MIRRORED.BY" );
$|++;
my @best = $cm->best_mirrors( 
  how_many => $how_many, verbose => 1, callback => sub { print "." }
);
print "Results:\n";
print "  " . $_->url . "\n" for @best;

