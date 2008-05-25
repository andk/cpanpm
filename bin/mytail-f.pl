#!/usr/bin/perl

=pod

with help from perlfaq5

Displays the whole file with leading line number and timestamp and
switches to 'tail -f' mode when the end is reached.

=cut

use Time::HiRes qw(time sleep);
my $curpos = 0;
my $line;
my $i = 0;
my $file = shift or die "Usage";
open GWFILE, $file or die "Could not open '$file': $!";
my $lines;
while (<GWFILE>) {
  $lines = $.;
}
close GWFILE;
open GWFILE, $file or die "Could not open '$file': $!";
for (;;) {
  for ($curpos = tell(GWFILE); $line = <GWFILE>; $curpos = tell(GWFILE)) {
    if (++$i > $lines - 10) {
      my @time = localtime;
      my $localtime = sprintf "%02d:%02d:%02d", @time[2,1,0];
      my $fractime = time;
      $fractime =~ s/\d+\.//;
      $fractime .= "0000";
      printf "%5d %s.%s %s", $i, $localtime, substr($fractime,0,4), $line;
    }
  }
  sleep 2;
  seek(GWFILE, $curpos, 0);  # seek to where we had been
}
