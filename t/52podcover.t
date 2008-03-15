# -*- mode: cperl -*-
use Test::More;
eval "use 5.00504";
plan skip_all => "perl 5.00504 required for this test" if $@;
eval "use Test::Pod::Coverage 0.18"; # 0.15 was misbehaving according to David Cantrell
plan skip_all => "Test::Pod::Coverage 0.18 required for testing pod coverage" if $@;
plan tests => 1;
my $trustme = { trustme => [ qw{
                                all_objects
                                anycwd
                                checklock
                                cleanup
                                delete
                                exists
                                find_perl
                                is_installed
                                is_tested
                                new
                                new
                                readhist
                                reset_tested
                                savehist
                                set_perl5lib
                                shell
                                soft_chdir_with_alternatives
                                suggest_myconfig
                              }]
              };
pod_coverage_ok( "CPAN", $trustme );
