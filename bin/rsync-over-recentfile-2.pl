#!/usr/bin/perl

=pod



=cut

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Spec;
use Getopt::Long qw(GetOptions);
use List::Util qw(min);
use Time::HiRes qw(sleep);

use lib "/home/k/sources/File-Rsync-Mirror-Recentfile/lib/";
require File::Rsync::Mirror::Recentfile;

our %Opt;
GetOptions(\%Opt,
           "use_interval=i",
           "loops=i",
           "verbose!",
          ) or die;

my %max_epoch_ever;

my $print_leading_newline = 0;
my $loop = 0;
ITERATION: while () {
  last if $Opt{loops} && $loop++ >= $Opt{loops};
  my $iteration_start = time;

  for my $rmodule (qw(authors modules)) {
    my $rf = File::Rsync::Mirror::Recentfile->new
        (
         canonize => "naive_path_normalize",
         filenameroot => "RECENT",
         ignore_link_stat_errors => 1,
         interval => q(6h),
         localroot => "/home/ftp/pub/PAUSE/$rmodule",
         remote_dir => $rmodule,
         remote_host => "k75",
         remote_module => "PAUSE",
         rsync_options => {
                           # intenionally not using archive=>1 because it contains "r"
                           compress => 0,
                           'rsync-path' => '/usr/bin/rsync',
                           links => 1,
                           times => 1,
                           'omit-dir-times' => 1,
                           checksum => 1,
                          },
         verbose => $Opt{verbose},
        );

    my $trecentfile = eval {$rf->get_remote_recentfile_as_tempfile();};
    if ($@) {
      warn sprintf "Warning: %s", $@; # XXX need a logging mechanism
      sleep 5;
      next ITERATION;
    }
    my($recent_data) = $rf->recent_events_from_tempfile();
    my @error;
    my $i = 0;
    my $total = @$recent_data;
  UPLOADITEM: for my $recent_event (reverse @$recent_data) {
      $i++;
      if ($recent_event->{type} eq "new"){
        my $must_get;
        $max_epoch_ever{$rmodule} ||= 0;
        if ($Opt{use_interval} && $recent_event->{epoch}+$Opt{use_interval} < time) {
          next UPLOADITEM;
        } elsif ($recent_event->{epoch} <= $max_epoch_ever{$rmodule}) {
          next UPLOADITEM;
        } else {
          $must_get++;
        }
        if ($must_get) {
          my $dst = $rf->local_event_path($recent_event->{path});
          my $doing = -e $dst ? "Syncing" : "Getting";
          {
            printf(
                   "%s%s (%d/%d) %s\n",
                   $print_leading_newline ? "\n" : "",
                   $doing,
                   $i,
                   $total,
                   $recent_event->{path},
                  );
            $print_leading_newline = 0;
          }
          eval { $rf->mirror_path($recent_event->{path}) };
          if ($@) {
            push @error, $@;
            sleep 1;
            next UPLOADITEM;
          }
        }
      } elsif ($recent_event->{type} eq "delete") {
        print "d";
      } else {
        warn "Warning: invalid upload type '$recent_event->{type}'"; # XXX logging
      }
      $max_epoch_ever{$rmodule} = $recent_event->{epoch} if $recent_event->{epoch} > $max_epoch_ever{$rmodule};
    }
    if (@error) {
      # XXX this seems a bit too drastic
      my $errors = @error;
      my @disperrors = splice @error, 0, min(10, scalar @error);
      my $disperrors = @disperrors;
      warn "Warning: Ran into $errors errors, $disperrors follow:
@disperrors
";
      sleep 12;
      $max_epoch_ever{$rmodule} = 0;
    }
    rename $trecentfile, $rf->recentfile;
  }

  my $minimum_time_per_loop = 60;
  { local $| = 1; print "."; $print_leading_newline = 1; }
  if (time - $iteration_start < $minimum_time_per_loop) {
    sleep $iteration_start + $minimum_time_per_loop - time;
  }
  { local $| = 1; print "~"; $print_leading_newline = 1; }
}

print "\n";

__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
