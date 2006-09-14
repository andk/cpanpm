# -*- mode: cperl -*-

use strict;
use File::Spec;
use Test::More;
use lib "lib";
require CPAN::HandleConfig;
my %keys = %CPAN::HandleConfig::keys;
my %special = map { $_ => undef } qw(
                                     dontload_hash
                                     mbuild_install_build_command
                                     make_install_make_command
                                    );
my %all = (%keys,%special);
plan tests => (
               scalar keys %all
              );

sub _f ($) {File::Spec->catfile(split /\//, shift);}

open my $fh, _f"lib/CPAN.pm" or die "Could not open CPAN.pm: $!";
my $seen;
while (<$fh>) {
  next if 1../^=head1 CONFIGURATION/;
  next if /^(\w|$)/ && !$seen;
  last if /^(\w|$)/ && $seen;
  chomp;
  my($leader,$gedoct) = unpack("a2 a40",$_);
  next if $gedoct =~ /^\s/;
  $gedoct =~ s/\s.*//;
  if (exists $keys{$gedoct}){
    delete $keys{$gedoct};
    $seen++;
    ok(1,"'$gedoct' doc'd");
  } elsif (exists $special{$gedoct}) {
    ok(1,"found doc'd for backwards compat: '$gedoct'");
  } else {
    ok(0,"found doc'd but not registered: '$gedoct'");
  }
}

ok(0,"missing docs: '$_'") for sort keys %keys;
