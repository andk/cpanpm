#!/usr/bin/perl

=pod

rev 3421 works but leaves a lock file around forever which cannot be deleted.

rev 3422 worked without a permanent lockfile. It has a lockfile that
is removed after the other file is written. Must not use another
process like "|sort > ...". When I tried this the other process was
usually not yet finished. May be slow on deadlock-like conditions
because it uses more and more time and rand. This needs to go away.



=cut

use strict;
use warnings;

use File::Temp;
use IO::Handle;
use Time::HiRes qw(sleep);

my($xfh,$rfile) = File::Temp::tempfile("qtulf-XXXX", DIR => "/tmp", CLEANUP => 0, SUFFIX => ".test");
close $xfh;

for my $i (0..99) {
  my $pid = fork;
  if (defined $pid) {
    if ($pid) {
      next;
    } else {
      my $slept = sleep rand $i/100;
      my $locked;
      {open my $lfh, ">", "$rfile.lock.$$" or die "Couldn't open '$rfile.lock': $!";}
      while (!$locked) {
        sleep 0.05;
        $locked = link "$rfile.lock.$$", "$rfile.lock";
      }
      unlink "$rfile.lock.$$";
      my $content = do { open my $tfh, $rfile or die $!; local $/; <$tfh> };
      $content .= "$$ $slept\n";
      open my $nfh, ">", "$rfile.new" or die "Couldn't open: $!";
      print $nfh $content;
      close $nfh or die "Could not close '> $rfile.new': $!";
      rename "$rfile.new", $rfile or die "Could not rename to '$rfile': $!";
      unlink "$rfile.lock";
      exit;
   }
  } else {
    die "fork test failed completely: $!";
  }
}
1 while wait > 0;
system 'wc', '-l', $rfile;
