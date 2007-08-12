#!/usr/bin/perl

use YAML::Syck;

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
my $recent = YAML::Syck::LoadFile "/home/ftp/pub/PAUSE/authors/id/RECENT-2d.yaml";
ITEM: for my $item (@$recent) {
  next unless $item->{path} =~ $rx;
  next unless $item->{type} eq "new";
  printf "%1s %s %s\n", ($max_epoch_worked_on && $max_epoch_worked_on == $item->{epoch}) ?
      "*" : "", scalar localtime $item->{epoch}, substr($item->{path},5);
}
