#!/usr/bin/perl -- -*- Mode: cperl; coding: utf-8; cperl-indent-level: 4 -*-

use strict;
use warnings;
use CPAN::DistnameInfo;
use File::Basename qw(dirname);
use Time::HiRes qw(sleep);
use YAML::Syck;

use lib "/home/k/dproj/PAUSE/SVN/lib/";
use PAUSE; # loads File::Rsync::Mirror::Recentfile for now

my $rf = File::Rsync::Mirror::Recentfile->new(
                                              canonize => "naive_path_normalize",
                                              localroot => "/home/ftp/pub/PAUSE/authors/id/",
                                              intervals => [qw(2d)],
                                             );

my $otherperls = "$0.otherperls";
my $statefile = "$ENV{HOME}/.cpan/loop-over-recent.state";

my $rx = qr!\.(tar.gz|tar.bz2|zip|tgz|tbz)$!;

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
  shift @perls while @perls && ! -x $perls[0];
  if (open my $fh2, $otherperls) {
    while (<$fh2>) {
      chomp;
      s/#.*//; # remove comments
      next if /^\s*$/; # remove empty/white lines
      next unless -x $_;
      push @perls, $_;
    }
  }
  my $recent_events = $rf->recent_events;
  $recent_events = [ grep { $_->{path} =~ $rx } @$recent_events ];
  {
    my %seen;
    $recent_events = [ grep { my $d = CPAN::DistnameInfo->new($_->{path});
                              !$seen{$d->dist}++
                            } @$recent_events ];
  }
 UPLOADITEM: for my $upload (reverse @$recent_events) {
    next unless $upload->{path} =~ $rx;
    next unless $upload->{type} eq "new";

    # never install stable reporters, they are most probably older
    # than we are.
    next if $upload->{path} =~ m!DAGOLDEN/CPAN-Reporter-0\.\d+\.tar\.gz!;

    # XXX: This needs to be extended to every distro that has a higher
    # numbered developer release. Say Foo-1.4801 is released but we
    # have already 1.48_51 installed. And we should not skip but 'make
    # test' instead of 'make install'. The problem with this is that
    # we do not know what exactly is in the distro. So we must go
    # through CPAN::DistnameInfo somehow. It gets even more
    # complicated when the item here gets passed to a queuerunner
    # because then the decision if test or install shall be called
    # cannot be made now, it must be made when the job is actually
    # started.

    if ($upload->{epoch} < $max_epoch_worked_on) {
      warn "Already done: $upload->{path}\n" unless keys %comboseen;
      sleep 0.1;
      next UPLOADITEM;
    } elsif ($upload->{epoch} == $max_epoch_worked_on) {
      if ($comboseen{"ALL",$upload->{path}}) {
        next UPLOADITEM;
      }
      warn "Maybe already worked on, we'll retry them: $upload->{path}";
    }
    {
      open my $fh, ">", $statefile or die "Could not open >$statefile\: $!";
      print $fh $upload->{epoch}, "\n";
      close $fh;
    }
    $max_epoch_worked_on = $upload->{epoch};
    my $epoch_as_localtime = scalar localtime $upload->{epoch};
  PERL: for my $perl (@perls) {
      my $perl_version =
          do { open my $fh, "$perl -e \"print \$]\" |" or die "Couldnt open $perl: $!";
               <$fh>;
             };
      my $combo = "|-> '$perl'(=$perl_version) <-> '$upload->{path}' ".
          "<-> '$epoch_as_localtime'(=$upload->{epoch}) <-|";
      if (0) {
      } elsif ($comboseen{$perl,$upload->{path}}){
        warn "dead horses combo $combo";
        sleep 2;
        next PERL;
      } else {
        warn "\n\n$combo\n\n\n";
        my $abs = File::Spec->catfile($rf->localroot, $upload->{path});
        {
          local $| = 1;
          while (! -f $abs) {
            print ",";
            sleep 5;
          }
        }
        $ENV{PERL_MM_USE_DEFAULT} = 1;
        $ENV{DISPLAY} = ":121";
        my @system = (
                      $perl,
                      "-Ilib",
                      "-MCPAN",
                      "-e",
                      "install '$upload->{path}'",
                     );
        # 0==system @system or die;
        unless (0==system @system){
          my $sleep = 30;
          warn "ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN\n";
          warn "      Something went wrong during\n";
          warn "      $perl\n";
          warn "      $upload->{path}\n";
          warn "      (sleeping $sleep)\n";
          warn "ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN-ATTN\n";
 	  sleep $sleep;
        }
        $comboseen{$perl,$upload->{path}} = $upload->{epoch};
      }
    }
    $comboseen{"ALL",$upload->{path}} = $upload->{epoch};
    next ITERATION; # see what is new before simply going through the ordered list
  }
  my $minimum_time_per_loop = 30;
  if (time - $iteration_start < $minimum_time_per_loop) {
    sleep $iteration_start + $minimum_time_per_loop - time;
  }
  for my $k (keys %comboseen) {
    delete $comboseen{$k} if $comboseen{$k} < time - 60*60*24*2;
  }
  { local $| = 1; print "."; }
}

print "\n";

__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
