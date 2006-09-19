# -*- mode: cperl -*-
use Test::More;
eval "use 5.00504";
plan skip_all => "perl 5.00504 required for this test" if $@;
eval "use Test::Pod::Coverage";
plan skip_all => "Test::Pod::Coverage required for testing pod coverage" if $@;
plan tests => 1;
my $trustme = { trustme => [ eval q{
  qr/
     (new
      |all_objects
      |checklock
      |cleanup
      |delete
      |exists
      |find_perl
      |is_installed
      |is_tested
      |new
      |savehist
      |set_perl5lib
      |soft_chdir_with_alternatives
      |suggest_myconfig
  )/x
}]};
pod_coverage_ok( "CPAN", $trustme );
