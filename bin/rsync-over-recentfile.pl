#!/usr/bin/perl

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Rsync;
use Time::HiRes qw(sleep);
use YAML::Syck;

my $localbase = "/home/ftp/pub/PAUSE/authors/id/";
my $recent = "RECENT-2d.yaml";
my $remotehost = "pause.perl.org";
my $remotemodule = "authors";
my $remotedir = "id";
my $remotebase = "$remotehost\::$remotemodule/$remotedir";

my $max_epoch_worked_on = 0;

my $rs = File::Rsync->new({
                           compress => 1,
                           'rsync-path' => '/usr/bin/rsync',
                          });
my %got_at;
ITERATION: while () {
  my $iteration_start = time;

  $rs->exec(
            src => "$remotebase/$recent",
            dst => "$localbase/$recent",
           ) or die $rs->err;
  my($recent_data) = YAML::Syck::LoadFile("$localbase/$recent");
 UPLOADITEM: for my $upload (reverse @$recent_data) {
    if ($upload->{type} eq "new"){
      my $must_get;
      if ($upload->{epoch} < $max_epoch_worked_on) {
        next UPLOADITEM;
      } elsif ($upload->{epoch} == $max_epoch_worked_on) {
        unless ($got_at{$upload->{path}}++) {
          $must_get++;
        }
      } else {
        $must_get++;
      }
      if ($must_get) {
        warn "Getting $upload->{path}\n";
        my $dst = "$localbase/$upload->{path}";
        mkpath dirname $dst;
        $rs->exec(
                  src => "$remotebase/$upload->{path}",
                  dst => $dst,
                 ) or die $rs->err;
        $got_at{$upload->{path}} = $upload->{epoch};
      }
    } else {
      warn "Warning: only 'new' implemented";
    }
    $max_epoch_worked_on = $upload->{epoch};
  }
  for my $k (keys %got_at) {
    delete $got_at{$k} if $got_at{$k} < time - 60*60*24*2;
  }
  my $minimum_time_per_loop = 20;
  { local $| = 1; print "~"; }
  if (time - $iteration_start < $minimum_time_per_loop) {
    sleep $iteration_start + $minimum_time_per_loop - time;
  }
  { local $| = 1; print "."; }
}

print "\n";
