#!/usr/bin/perl

use strict;
use warnings;
use CPAN::DistnameInfo;
use File::Basename qw(dirname);
use Time::HiRes qw(sleep);
use YAML::Syck;

my $recent = "/home/ftp/pub/PAUSE/authors/id/RECENT-2d.yaml";
my $otherperls = "$0.otherperls";
my $statefile = "$ENV{HOME}/.cpan/loop-over-recent.state";

my @perls = qw(); # we'll fill it at runtime!

my $max_epoch_worked_on = 0;
if (-e $statefile) {
  local $/;
  my $state = do { open my $fh, $statefile or die "Couldn't open '$statefile': $!";
                   <$fh>;
                 };
  chomp $state;
  $state += 0;
  $max_epoch_worked_on = $state if $state;
}
warn "max_epoch_worked_on[$max_epoch_worked_on]";
my $basedir = "/home/sand/CPAN-SVN/logs";
my %comboseen;
my %have_warned;
ITERATION: while () {
  my $iteration_start = time;
  opendir my $dh, $basedir or die;
  my @perls = sort grep { /^megainstall\..*\.d$/ } readdir $dh;
  pop @perls while ! -e "$basedir/$perls[-1]/perl-V.txt";
  shift @perls while @perls>1;
  {
    open my $fh, "$basedir/@perls/perl-V.txt" or die;
    while (<$fh>) {
      next unless /-Dprefix=(\S+)/;
      @perls = "$1/bin/perl";
      last;
    }
    close $fh;
  }
  if (open my $fh2, $otherperls) {
    while (<$fh2>) {
      chomp;
      next unless -x $_;
      push @perls, $_;
    }
  }
  my($recent_data) = YAML::Syck::LoadFile($recent);
  $recent_data = [ grep { $_->{path} =~ m!\.(tar.gz|tar.bz2|\.zip)$! } @$recent_data ];
  {
    my %seen;
    $recent_data = [ grep { my $d = CPAN::DistnameInfo->new($_->{path});
                            !$seen{$d->dist}++
                          } @$recent_data ];
  }
 UPLOADITEM: for my $upload (reverse @$recent_data) {
    next unless $upload->{path} =~ m!\.(tar.gz|tar.bz2|\.zip)$!;
    next unless $upload->{type} eq "new";
    # never install stable reporters, they are most probably older
    # than we are
    next if $upload->{path} =~ m!DAGOLDEN/CPAN-Reporter-0\.\d+\.tar\.gz!;
    if ($upload->{epoch} <= $max_epoch_worked_on) {
      warn "Skipping already handled $upload->{path}\n" unless $have_warned{$upload->{path}}++;
      sleep 0.1;
      next UPLOADITEM;
    }
    {
      open my $fh, ">", $statefile or die "Could not open >$statefile\: $!";
      print $fh $upload->{epoch}, "\n";
      close $fh;
    }
    $max_epoch_worked_on = $upload->{epoch};
    my $epoch_as_localtime = scalar localtime $upload->{epoch};
    for my $perl (@perls) {
      next unless -x $perl;
      my $perl_version = do { open my $fh, "$perl -e \"print \$]\" |" or die "Couldnt open $perl: $!";
                              <$fh>;
                            };
      my $combo = "|-> '$perl'(=$perl_version) <-> '$upload->{path}' <-> '$epoch_as_localtime'(=$upload->{epoch}) <-|";
      if (0) {
      } elsif ($comboseen{$perl,$upload->{path}}++){
        warn "dead horses combo $combo";
        sleep 5;
        next UPLOADITEM;
      } else {
        warn "\n\n$combo\n\n\n";
        my $abs = dirname($recent) . "/$upload->{path}";
        while (! -f $abs) {
          local $| = 1;
          print ".";
          sleep 5;
        }
        $ENV{PERL_MM_USE_DEFAULT} = 1;
        my @system = (
                      $perl,
                      "-Ilib",
                      "-MCPAN",
                      "-e",
                      "install '$upload->{path}'",
                     );
        # 0==system @system or die;
        unless (0==system @system){
          warn "ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN\n";
          warn "      Something went wrong during\n";
          warn "      $perl\n";
          warn "      $upload->{path}\n";
          warn "ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN\n";
 	  sleep 60;
        }
      }
    }
    next ITERATION; # see what is new before simply going through the ordered list
  }
  # guaratee a minimum of 60 seconds per loop
  if (time - $iteration_start < 60) {
    sleep 60 - (time - $iteration_start);
  }
  { local $| = 1; print "."; }
}

print "\n";
