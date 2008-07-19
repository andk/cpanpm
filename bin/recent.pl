#!/usr/bin/perl

=head1 NAME

recent - 

=head1 SYNOPSIS

 watch -t -n 20 'perl ~k/sources/CPAN/GIT/trunk/bin/recent.pl -n 25 --burn-in-protection'

=head1 DESCRIPTION

Show most recent uploads according to the RECENT file and mark the
currently processing one (according to ~/.cpan/loop-over-recent.state
with a star.

The burn-in-protection changes something from time to time. This also
cleans up STDERR remnants that otherwise might annoy the user of
watch(1).

=cut

use strict;
use warnings;

use CPAN::DistnameInfo;
use Getopt::Long;
use YAML::Syck;

our %Opt;
GetOptions(\%Opt,
           "n=i",
           "burn-in-protection|lossy!",
           "alternative=i",
          );
use lib "/home/k/sources/File-Rsync-Mirror-Recentfile/lib/";
use File::Rsync::Mirror::Recentfile;

my $statefile = "$ENV{HOME}/.cpan/loop-over-recent.state";
my $max_epoch_worked_on = 0;

my $rx = qr!\.(tar.gz|tar.bz2|zip|tgz|tbz)$!; # see also loop-over...

if (-e $statefile) {
  local $/;
  my $state = do { open my $fh, $statefile or die "Couldn't open '$statefile': $!";
                   <$fh>;
                 };
  chomp $state;
  $state += 0;
  $max_epoch_worked_on = $state if $state;
}
my $rf1 = File::Rsync::Mirror::Recentfile->new(
                                               canonize => "naive_path_normalize",
                                               localroot => "/home/ftp/pub/PAUSE/authors/id/",
                                               interval => q(2d),
                                              );
my $rf2 = File::Rsync::Mirror::Recentfile->new(
                                               canonize => "naive_path_normalize",
                                               localroot => "/home/ftp/pub/PAUSE/authors/",
                                               interval => q(6h),
                                               filenameroot => "RECENT",
                                              );
$Opt{alternative} ||= 2;
my $rf;
if ($Opt{alternative}==1) {
  $rf = $rf1;
} elsif ($Opt{alternative}==2) {
  $rf = $rf2;
}
my $have_a_current = 0;
my $recent_events = $rf->recent_events;
{
  my %seen;
  $recent_events = [ grep { my $d = CPAN::DistnameInfo->new($_->{path});
                            no warnings 'uninitialized';
                            !$seen{$d->dist}++
                                && $_->{path} =~ $rx
                                    && $_->{type} eq "new";
                          } @$recent_events ];
  for my $re (@$recent_events) {
    if ($re->{epoch} == $max_epoch_worked_on) {
      $re->{is_current} = 1;
      $have_a_current = 1;
    }
  }
}
my $count = 0;
ITEM: for my $i (0..$#$recent_events) {
  my $item = $recent_events->[$i];
  my $mark = "";
  if ($max_epoch_worked_on) {
    if ($item->{is_current}) {
      $mark = "*";
    } elsif (!$have_a_current
             && $max_epoch_worked_on > $item->{epoch}
             && $i > 0
             && $max_epoch_worked_on < $recent_events->[$i-1]->{epoch}) {
      printf "%1s %s\n", "*", scalar localtime $max_epoch_worked_on;
    }
  }
  my $line = sprintf "%1s %s %s\n", $mark, scalar localtime $item->{epoch}, substr($item->{path},$Opt{alternative}==1 ? 5 : 8);
  if ($Opt{"burn-in-protection"}) {
    chomp $line;
    while (rand 30 < 1) {
      $line = " $line";
    }
    if (length($line) > 80) {
      while (length($line) > 80){
        chop($line);
      }
      substr($line,80-1,1) = rand(30)<1 ? "_" : ">";
    }
    while (length($line) < 80){
      $line .= rand(30)<1 ? "_" : " ";
    }
    if (rand(30)<1) {
      $line =~ s/ /_/g;
    }
    $line .= "\n";
  }
  print $line;
  if ($Opt{n} && ++$count>=$Opt{n}) {
    last ITEM;
  }
}
if (0 == $count) {
  print sprintf "  found nothing of interest in %s\n", $rf->recentfile_basename;
} elsif ($count < $Opt{n}) {
  while ($count < $Opt{n}) {
    my $line = "";
    while (length($line) < 80){
      $line .= rand(30)<1 ? "_" : " ";
    }
    print "$line\n";
    $count++;
  }
}
__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
