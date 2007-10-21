#!/usr/bin/perl

=pod

rev 3421 works but leaves a lock file around forever which cannot be deleted.

=cut

use strict;
use warnings;

use Fcntl qw(:flock);
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
      my $lfh;
      my $locked;
      my $j;
      while (!$locked) {
        sleep rand(++$j/1000);
        open $lfh, ">", "$rfile.lock" or die "Couldn't open '$rfile.lock': $!";
        $locked = flock $lfh, LOCK_EX|LOCK_NB or close $lfh;
      }
      my $content = do { open my $tfh, $rfile or die $!; local $/; <$tfh> };
      $content .= "$$ $slept\n";
      open my $nfh, ">", "$rfile.new" or die "Couldn't fork: $!";
      print $nfh $content;
      close $nfh or die "Could not close 'sort > $rfile'.new: $!";
      rename "$rfile.new", $rfile or die "Could not rename to '$rfile': $!";
      unlink "$rfile.lock";
      close $lfh or die;
      exit;
   }
  } else {
    die "fork test failed completely: $!";
  }
}
1 while wait > 0;
system 'cat', '-n', $rfile;
