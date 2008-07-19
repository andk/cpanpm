#!/usr/bin/perl

=pod

File::Rsync::Mirror::Recentfile?

need a field mirroring_from: consisting of host, module, path,
authentification_needed,

keep the very first item in the got_at hash. we cannot know if this
second has been fully processed. On the next loop we need to look into
the got_at hash. if nothing happens for a full interval's length the
current code would delete this item. UPDATE: when removing at the end
of the loop just change "< time ..." to "< $max_epoch ..." DONE

The got_at hash must die. That's solved with floating point time. We
never have two items with the same timestamp.

Q: sorted by epoch? Who has to sort when how often? A: nobody! The
mechanism is "event" based and the array is only running push and
shift (and grep). It is a journal (that throws memory away based on an
interval) and is itself NOT rsynced but in fact (?) rewritten by every
slave. [journaling fs are not so much related because they throw away
after having written] Do slaves inherit the timestamp from the master
or do they write their own? I think they inherit it (Update 2007-10-21
akoenig : or we do not ever promise that the timestamps are sorted or
mirror the sequence of events or we make them floating point numbers
so they become uniq and can be treated as hash keys [this I like!]).
But then they must not mirror events in a later second before all
seconds below are finished (Update 2007-10-21 akoenig : this can be
relaxed).

      M       St1       St2       St3       St4

   4711: A  4711: A   4711: A   4711: A   4711: A
   4711: B            4711: B   4711: B   4711: B
   4711: C                      4711: C   4711: C
   4712: D                                4712: D

Update 2007-10-21 akoenig no 4711 timestamp evar! They become
4711.xxxx, 4711.xxxy, etc. OR something like UUID. But if two hosts
differ in the order, comparing them is less simple.

Interesting/Ugly is the second generation problem if we let the recent
file be written to disk too early. We should not write as long as it
contains files yet to be mirrored. Easiest solved with File::Temp.
Make a random filename for each loop and rename at the end. DONE

Interesting/Advanced is the idea to write a new RECENT file at the end
of the inner loop. When a server falls behind for some reason and
catches up, then the dependents recover much earlier. LATER (needs the
write_recent routines in a module).

Stupid is the idea to rewrite large files as
chunks to be concatenated later.

Stupid is the idea to allow an
operation "rename". Mirror remote files to temporary local filenames,
then move these to the final name. After every X megabyte a RECENT
file is written including the currently running mirrored file with its
temporary name. Then the rename op is written to the RECENT file. Lots
of race conditions, certainly solvable but a bit complicated. (Update
2007-10-21 akoenig maybe a copy operation is better)

Bug/Trap: files in recent that do not exist at the source. If we get
no RECENT file we just wait until we get one again. Other files that
we miss? $degraded_mode? Most conservative approach: reset
$max_epoch_ever, do not pass on this recent file, retry the whole
collection. The last bit is drastic but given that rsync can handle
files quickly that are OK makes it not look that catastrophic. DONE.

Interesting/Funny is the idea that dependents fetch files from each
other.

If dependents merge RECENT files from the peers this would lead to the
trap that some objects get added to an older second and the algorithm
would have to invalidate $max_epoch_ever. So if they do not merge
RECENT files it is easy, otherwise it gets ugly.

Interesting/intimidating is the idea that the statistics done by
Pennink(sp?) suddenly might get less reliable.

Reconsidering the whole: if slaves only write RECENT files reflecting
what they already have got, valuable information gets lost. If they
write complete and unaltered RECENT files they lead the 2nd generation
slaves down the wrong road. Solution might be: they add to the RECENT
file the information what they already have. got_at => $epoch? have =>
1? status => "todo"? Think of errors/retry status. reminds me of
nosuccess_count and nosuccess_time in the pause daemon.

and we want deprecation of the whole modules/by_* directories.

=cut

use strict;
use warnings;
use File::Basename qw(dirname);
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

my %got_at;
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
         remote_dir => "",
         remote_host => "pause.perl.org",
         remote_module => $rmodule,
         rsync_options => {
                           # intenionally not using archive=>1 because it contains "r"
                           compress => 1,
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
        } elsif ($recent_event->{epoch} < $max_epoch_ever{$rmodule}) {
          next UPLOADITEM;
        } elsif ($recent_event->{epoch} == $max_epoch_ever{$rmodule}) {
          unless ($got_at{$recent_event->{path}}++) {
            $must_get++;
          }
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
          $got_at{$recent_event->{path}} = $recent_event->{epoch};
        }
      } elsif ($recent_event->{type} eq "delete") {
        # note that we should not delete files on CPAN immediately
        # before the indexes are adjusted. This is probably a bug in
        # the CPAN system but the problem might be quite common.

        # the mirror master should always adjust his indexes before
        # actually deleting files. Or at least rewrite the index
        # immediately after a couple of deletes. Fortunately the cpan
        # system usually only deletes files that are in no index
        # anymore (but people make mistakes)
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
      %got_at = ();
    } else {
      for my $k (keys %got_at) {
        delete $got_at{$k} if $got_at{$k} < $max_epoch_ever{$rmodule} - 60*60*24*2;
      }
    }

    # XXX broken: we must do something else when an error happens. I
    # think we must rewrite the recent file and set the eventtype to
    # unknown or something. But we must publish *some* recent file
    # otherwise a single error stops the whole mirroring process. In our
    # case it was a file that got deleted at the source but it was not
    # reflected in the RECENT file. We must never believe that the R
    # file is perfect.

    # Note: by setting the max_time_ever to zero we might also do harm
    # insofar we hit the parent server to often with all the files that
    # are OK. We should probably only retry the files that have an
    # error, like in a nosuccesscount and nosuccesstime and retry rate.

    rename $trecentfile, $rf->recentfile;
  }

  my $minimum_time_per_loop = 20;
  { local $| = 1; print "."; $print_leading_newline = 1; }
  if (time - $iteration_start < $minimum_time_per_loop) {
    # last ITERATION;
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
