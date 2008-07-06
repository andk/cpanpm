#!/usr/bin/perl -- -*- Mode: cperl; coding: utf-8; cperl-indent-level: 4 -*-

use strict;
use warnings;
use CPAN::DistnameInfo;
use File::Basename qw(fileparse dirname);
use Time::HiRes qw(sleep);
use YAML::Syck;

use lib "/home/k/dproj/PAUSE/wc/lib/";
use PAUSE; # loads File::Rsync::Mirror::Recentfile for now

sub determine_perls {
  my($basedir,$otherperls) = @_;
  my @perls;
  my $trust_latest_bleadperls = 1;
  if ($trust_latest_bleadperls) {
    opendir my $dh, $basedir or die;
    my @perls = sort grep { /^megainstall\..*\.d$/ } readdir $dh;
    pop @perls while ! -e "$basedir/$perls[-1]/perl-V.txt";
  PERL: while (@perls) {
      open my $fh, "$basedir/$perls[-1]/perl-V.txt" or die;
      while (<$fh>) {
        next unless /-Dprefix=(\S+)/;
        my $perl = "$1/bin/perl";
        if (-x $perl){
          @perls = $perl; # only one survives
          last PERL;
        } else {
          pop @perls;
        }
      }
      close $fh;
    }
    shift @perls while @perls && ! -x $perls[0];
  }
  if (open my $fh2, $otherperls) {
    while (<$fh2>) {
      chomp;
      s/#.*//; # remove comments
      next if /^\s*$/; # remove empty/white lines
      next unless -x $_;
      push @perls, $_;
    }
  }
  \@perls;
}

sub read_recent_events {
  my($rf,$rx) = @_;
  my $recent_events = $rf->recent_events;
  $recent_events = [ grep { $_->{path} =~ $rx } @$recent_events ];
  {
    my %seen;
    $recent_events = [ grep {
      my $path = $_->{path};
      my $d = CPAN::DistnameInfo->new($path);
      my $dist = $d->dist;
      # warn "no dist for path[$path]" unless $dist;
      $dist ? !$seen{$dist}++ : "";
    } @$recent_events ];
  }
  $recent_events;
}

MAIN : {
  my $rf = File::Rsync::Mirror::Recentfile->new(
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

  my $otherperls = "$0.otherperls";
  my $bbname = fileparse($0,qr{\.pl});
  my $statefile = "$ENV{HOME}/.cpan/$bbname.state";
  my $rx = qr!\.(tar.gz|tar.bz2|zip|tgz|tbz)$!;
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
    my $recent_events = read_recent_events($rf2,$rx);
    my $perls;
    # my @good_recent_events; # ? first collect them, then only if we
    # have something go ahead?
  UPLOADITEM: for my $upload (reverse @$recent_events) {
      next unless $upload->{path} =~ $rx;
      next unless $upload->{type} eq "new";
      next if $upload->{path} =~ m|^R/RG/RGARCIA/perl-5.10|;
      my $action = "install";
      if ($upload->{path} =~ m|^D/DA/DAGOLDEN/CPAN-Reporter-\d+\.\d+_|){
        $action = "test";
      }
      
      # XXX: we should compute exceptions for every distro that has a
      # higher numbered developer release. Say Foo-1.4801 is released
      # but we have already 1.48_51 installed. We do not want this
      # stable stuff. Test yes, so we should 'make test' instead of
      # 'make install'. The problem with this is that we do not know
      # what exactly is in the distro. So we must go through
      # CPAN::DistnameInfo somehow. It gets even more complicated when
      # the item here gets passed to a queuerunner because then the
      # decision if test or install shall be called cannot be made now,
      # it must be made when the job is actually started.
      
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
      $perls ||= determine_perls($basedir,$otherperls);
    PERL: for my $perl (@$perls) {
        my $perl_version =
            do { open my $fh, "$perl -e \"print \$]\" |" or die "Couldnt open $perl: $!";
                 <$fh>;
               };
        my $testtime = localtime;
        my $combo = "perl|-> $perl (=$perl_version)\npath|-> $upload->{path}\n".
            "recv|-> $epoch_as_localtime (=$upload->{epoch})\ntime|-> $testtime";
        if (0) {
        } elsif ($comboseen{$perl,$upload->{path}}){
          warn "dead horses combo $combo";
          sleep 2;
          next PERL;
        } else {
          warn "\n\n$combo\n\n\n";
          my $abs = File::Spec->catfile($rf2->localroot, $upload->{path});
          {
            local $| = 1;
            while (! -f $abs) {
              print ",";
              sleep 5;
            }
          }
          $ENV{PERL_MM_USE_DEFAULT} = 1;
          $ENV{AUTOMATED_TESTING} = 1;
          $ENV{DISPLAY} = ":121";
          my $distro = $upload->{path};
          $distro =~ s|^id/||;
          my @system = (
                        $perl,
                        "-Ilib",
                        "-I$ENV{HOME}/.cpan",
                        "-MCPAN::MyConfig",
                        "-MCPAN",
                        "-e",
                        "\$CPAN::Config->{build_dir_reuse}=0; $action q{$distro}",
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

}

__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
