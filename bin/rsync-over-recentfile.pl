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
           "loops=i",
           "verbose!",
          ) or die;

my $loop = 0;
my %reached;
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

    $rf->mirror(after => $reached{$rmodule}||0);
    my $re = $rf->recent_events;
    $reached{$rmodule} = $re->[0]{epoch};
  }
  $reached{now} = time;
  require YAML::Syck; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . YAML::Syck::Dump(\%reached); # XXX

  my $minimum_time_per_loop = 20;
  my $sleep = $iteration_start + $minimum_time_per_loop - time;
  if ($sleep > 0.01) {
    sleep $sleep;
  } else {
    # negative time not invented yet
  }
}

print "\n";

__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
