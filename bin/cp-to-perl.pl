#!/usr/bin/perl

=pod

Script to copy those files that live also in the core into a perl
source tree.

I use it such that I first make a branch of bleadperl:

    git checkout blead
    git pull
    git checkout -b orange93

Then I use cp-to-perl to clobber the branch:

    sudo -u sand perl bin/cp-to-perl.pl /home/src/perl/repoperls/perl5.git.perl.org/perl

Test and then do in git over there

    # edit manifest if necessary
    # make manisort
    git add ...
    git commit -m 'Update CPAN.pm to xxx' -a
    git format-patch origin

=head2 TODO

Bringing tests over is of minor importance to me, so far my test
scripts have never caught a bug in perl. And they are timeconsuming
and not really small. I'd dislike to bloat perl with them. Small
tests, probably. But they have dependencies, e.g. on local_utils.pm

=cut

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Copy qw(cp);
use Term::Prompt;

my $target = shift or die "Usage: $0 targetdirectory";
die "Could not find directory '$target'" unless -d $target;
$target =~ s|/+$||;
# warn "Copying to '$target'\n";

my $MAP;
{
  no warnings 'qw';
  $MAP = {
          "" => ["cpan/CPAN/lib/CPAN/" => [qw(
                                     PAUSE*.pub
                                     SIGNATURE
                                   )]],
          "lib/" => ["cpan/CPAN/lib/"  => [qw(
                                    lib/CPAN.pm
                                    lib/CPAN/API/HOWTO.pod
                                    lib/CPAN/Author.pm
                                    lib/CPAN/Bundle.pm
                                    lib/CPAN/CacheMgr.pm
                                    lib/CPAN/Complete.pm
                                    lib/CPAN/Debug.pm
                                    lib/CPAN/DeferredCode.pm
                                    lib/CPAN/Distribution.pm
                                    lib/CPAN/Distroprefs.pm
                                    lib/CPAN/Distrostatus.pm
                                    lib/CPAN/Exception/RecursiveDependency.pm
                                    lib/CPAN/Exception/blocked_urllist.pm
                                    lib/CPAN/Exception/yaml_not_installed.pm
                                    lib/CPAN/FTP.pm
                                    lib/CPAN/FTP/netrc.pm
                                    lib/CPAN/FirstTime.pm
                                    lib/CPAN/HandleConfig.pm
                                    lib/CPAN/Index.pm
                                    lib/CPAN/InfoObj.pm
                                    lib/CPAN/Kwalify.pm
                                    lib/CPAN/Kwalify/distroprefs.dd
                                    lib/CPAN/Kwalify/distroprefs.yml
                                    lib/CPAN/LWP/UserAgent.pm
                                    lib/CPAN/Module.pm
                                    lib/CPAN/Nox.pm
                                    lib/CPAN/Prompt.pm
                                    lib/CPAN/Queue.pm
                                    lib/CPAN/Shell.pm
                                    lib/CPAN/Tarzip.pm
                                    lib/CPAN/URL.pm
                                    lib/CPAN/Version.pm
                                   )]],
          "scripts/" => ["cpan/CPAN/scripts/" => [qw(
                                                scripts/cpan
                                               )]],
          "t/" => ["cpan/CPAN/t/" => [qw(
                                        t/{01,02,03,10,11}*.t
                                       )]], # loadme, mirroredby, nox, vcmp, version
         };
}

my @command;
while (my($here,$v) = each %$MAP) {
  my($theredir,$files) = @$v;
  for my $file (@$files) {
    my $prefix_length = length($here);
    die "bad file[$file]" unless substr($file,0,$prefix_length) eq $here;
    my @expand_file = glob($file);
    for my $efile (@expand_file) {
      my @c = ("cp", $efile);
      my $target_file = sprintf "%s/%s%s", $target, $theredir, substr($efile,$prefix_length);
      unless (-d dirname $target_file) {
          push @command, [ "mkdir", dirname $target_file ];
      }
      push @c, $target_file;
      printf "%s %-21s %s\n", @c;
      push @command, \@c;
    }
  }
}

exit unless prompt("y","Proceed?","","y");
for my $c (@command) {
    if ($c->[0] eq "cp") {
        shift @$c;
        unlink $c->[1] or warn "Warning: Could not unlink the target $c->[1]: $!";
        cp @$c or die "Alert: Could not cp $c->[0] to $c->[1]: $!";
    } elsif ($c->[0] eq "mkdir") {
        require File::Path;
        File::Path::mkpath($c->[1]);
    } else {
        die;
    }
}

