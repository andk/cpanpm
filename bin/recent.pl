#!/usr/bin/perl

use CPAN::DistnameInfo;
use YAML::Syck;

use lib "/home/k/dproj/PAUSE/wc/lib/";
use PAUSE; # loads File::Rsync::Mirror::Recentfile for now

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
my $rf = File::Rsync::Mirror::Recentfile->new(
                                              canonize => "naive_path_normalize",
                                              localroot => "/home/ftp/pub/PAUSE/authors/id/",
                                              intervals => [qw(2d)],
                                             );

my $recent_events = $rf->recent_events;
{
  my %seen;
  $recent_events = [ grep { my $d = CPAN::DistnameInfo->new($_->{path});
                            !$seen{$d->dist}++
                          } @$recent_events ];
}
ITEM: for my $item (@$recent_events) {
  next unless $item->{path} =~ $rx;
  next unless $item->{type} eq "new";
  printf "%1s %s %s\n", ($max_epoch_worked_on && $max_epoch_worked_on == $item->{epoch}) ?
      "*" : "", scalar localtime $item->{epoch}, substr($item->{path},5);
}
