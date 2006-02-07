#!/usr/bin/perl

=pod

Script to copy those files that live also in the core into a perl
source tree.

=cut

use strict;
use warnings;
use File::Copy qw(cp);
use Term::Prompt;

my $target = shift or die "Usage: $0 targetdirectory";
die "Could not find directory '$target'" unless -d $target;
$target =~ s|/+$||;
# warn "Copying to '$target'\n";

my $MAP = {
           "" => ["lib/CPAN/" => [qw(
                                     SIGNATURE
                                     PAUSE*.pub
                                    )]],
           "lib/" => ["lib/"  => [qw(
                                     lib/CPAN.pm
                                     lib/CPAN/Debug.pm
                                     lib/CPAN/FirstTime.pm
                                     lib/CPAN/HandleConfig.pm
                                     lib/CPAN/Nox.pm
                                     lib/CPAN/Tarzip.pm
                                     lib/CPAN/Version.pm
                                    )]],
           "scripts/" => ["lib/CPAN/bin/" => [qw(
                                                 scripts/cpan
                                                )]],
           "t/" => ["lib/CPAN/t/" => [qw(
                                         t/[lmNv]*.t
                                        )]], # loadme, mirroredby, nox, vcmp, version
          };

my @command;
while (my($here,$v) = each %$MAP) {
  my($theredir,$files) = @$v;
  for my $file (@$files) {
    my $prefix_length = length($here);
    die "bad file[$file]" unless substr($file,0,$prefix_length) eq $here;
    my @expand_file = glob($file);
    for my $efile (@expand_file) {
      my @c = $efile;
      push @c, sprintf "%s/%s%s", $target, $theredir, substr($efile,$prefix_length);
      printf "cp %-21s %s\n", @c;
      push @command, \@c;
    }
  }
}

exit unless prompt("y","Proceed?","","y");
for my $c (@command) {
  cp @$c or die "Could not cp @$c";
}
