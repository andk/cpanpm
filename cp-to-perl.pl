#!/usr/bin/perl

use strict;
use warnings;
use File::Copy qw(cp);
use Term::Prompt;

my $target = shift or die "Usage: $0 targetdirectory";
die "Could not find directory '$target'" unless -d $target;
$target =~ s|/+$||;
# warn "Copying to '$target'\n";

=pod

lib/CPAN/bin/cpan		easily interact with CPAN from the command line
lib/CPAN/FirstTime.pm		Utility for creating CPAN config files
lib/CPAN/Nox.pm			Runs CPAN while avoiding compiled extensions
lib/CPAN/PAUSE2003.pub		CPAN public key
lib/CPAN/PAUSE2005.pub		CPAN public key
lib/CPAN/SIGNATURE		CPAN public key
lib/CPAN/Version.pm		Simple math with different flavors of version strings
lib/CPAN.pm			Interface to Comprehensive Perl Archive Network
lib/CPAN/t/loadme.t		See if CPAN the module works
lib/CPAN/t/mirroredby.t		See if CPAN::Mirrored::By works
lib/CPAN/t/Nox.t		See if CPAN::Nox works
lib/CPAN/t/vcmp.t		See if CPAN the module works
lib/CPAN/t/version.t		See if CPAN::Version works

=cut

my $MAP = {
           "" => ["lib/CPAN/" => [qw(
                                     SIGNATURE
                                     PAUSE*.pub
                                    )]],
           "lib/" => ["lib/"  => [qw(
                                     lib/CPAN.pm
                                     lib/CPAN/FirstTime.pm
                                     lib/CPAN/Nox.pm
                                     lib/CPAN/Version.pm
                                    )]],
           "scripts/" => ["lib/CPAN/bin/" => [qw(
                                                 scripts/cpan
                                                )]],
           "t/" => ["lib/CPAN/t/" => [qw(
                                         t/[lmNv]*.t
                                        )]], # not signature!
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
