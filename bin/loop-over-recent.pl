#!/usr/bin/perl

use strict;
use warnings;
use File::Basename qw(dirname);
use YAML::Syck;

my $recent = "/home/ftp/pub/PAUSE/authors/id/RECENT-2d.yaml";
my $otherperls = "$0.otherperls";

my @perls = qw(); # we'll fill it at runtime!

my %seen;

my $max_epoch_worked_on = 0;
ITERATION: while () {
  my $basedir = "/home/sand/CPAN-SVN/logs";
  opendir my $dh, $basedir or die;
  my @perls = sort grep { /^megainstall\..*\.d$/ } readdir $dh;
  pop @perls while ! -e "$basedir/$perls[-1]/perl-V.txt";
  shift @perls while @perls>1;
  open my $fh, "$basedir/@perls/perl-V.txt" or die;
  while (<$fh>) {
    next unless /-Dprefix=(\S+)/;
    @perls = "$1/bin/perl";
    last;
  }
  if (open my $fh2, $otherperls) {
    while (<$fh2>) {
      chomp;
      next unless -x $_;
      push @perls, $_;
    }
  }
  my($recent_data) = YAML::Syck::LoadFile($recent);
  my $max_epoch_this_time = 0;
 UPLOADITEM: for my $upload (reverse @$recent_data) {
    next unless $upload->{path} =~ m!\.(tar.gz|tar.bz2)$!;
    next unless $upload->{type} eq "new";
    $max_epoch_this_time ||= $upload->{epoch};
    if ($upload->{epoch} <= $max_epoch_worked_on) {
      last UPLOADITEM;
    }
    for my $perl (@perls) {
      my $combo = " '$perl' <-> '$upload->{path}' ";
      if (0) {
      } elsif ($seen{$perl,$upload->{path}}++){
        warn "dead horses combo $combo";
        sleep 30;
        next ITERATION;
      } else {
        warn "Going to treat combo $combo";
        $ENV{PERL_MM_USE_DEFAULT} = 1;
        my @system = (
                      $perl,
                      "-Ilib",
                      "-MCPAN",
                      "-e",
                      "install '$upload->{path}'",
                     );
        0==system @system or die;
      }
    }
  }
  $max_epoch_worked_on = $max_epoch_this_time;
}

print "\n";
