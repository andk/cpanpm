#!/usr/bin/perl

=pod

todo:

change format of the yaml file to contain protocol number and a status
field that links to some protocol spec.
File::Rsync::Mirror::Recentfile?

in any case we want protocol => 2 for the next version and we want a
field that tells us in human readable language what this tree is about.

and a field mirroring_from: consisting of host, module, path,
authentification_needed, 

add interval (2d) of the whole file to the metadata.

keep the very first item in the got_at hash. we cannot know if this
second has been fully processed. On the next loop we need to look into
the get_at hash. if nothing happens for a full interval's length the
current code would delete this item. UPDATE: when removing at the end
of the loop just change "< time ..." to "< $max_epoch ..." DONE

Q: sorted by epoch? Who has to sort when how often? A: nobody! The
mechanism is event based and the array is only running push and shift.
It is a journal and is itself NOT rsynced but in fact rewritten by
every slave. [find literature about journaling fs!] Do slaves
inherit the timestamp from the master or do they write their own? I
think they inherit it. But then they must not mirror events in a later
second before all seconds below are finished.

      M       St1       St2       St3       St4

   4711: A  4711: A   4711: A   4711: A   4711: A
   4711: B            4711: B   4711: B   4711: B
   4711: C                      4711: C   4711: C
   4712: D                                4712: D

Interesting/Ugly is the second generation problem if we let the recent
file be written to disk too early. We should not write as long as it
contains files yet to be mirrored. Easiest solved with File::Temp.
Make a random filename for each loop and rename at the end. DONE

Interesting/Advanced is the idea to write a new RECENT file at the end
of the inner loop. When a server falls behind for some reason and
catches up, then the dependents recover much earlier. LATER (needs the
write_recent routines in a module).

Interesting/Superadvanced/Stupid is the idea to rewrite large files as
chunks to be concatenated later.

Interesting/Superadvanced/Complicated is the idea to allow an
operation "rename". Mirror remote files to temporary local filenames,
then move these to the final name. After every X megabyte a RECENT
file is written including the currently running mirrored file with its
temporary name. Then the rename op is written to the RECENT file. Lots
of race conditions, certainly solvable but a bit complicated.

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
use File::Path qw(mkpath);
use File::Rsync;
use File::Spec;
use File::Temp ();
use Time::HiRes qw(sleep);
use YAML::Syck;

use lib "/home/k/dproj/PAUSE/SVN/lib/";
use PAUSE; # loads File::Rsync::Mirror::Recentfile for now

my $rf = File::Rsync::Mirror::Recentfile->new(
                                              canonize => "naive_path_normalize",
                                              localroot => "/home/ftp/pub/PAUSE/authors/id/",
                                              intervals => [qw(2d)],
                                             );

my $recent = "RECENT-2d.yaml";
my $remotehost = "pause.perl.org";
my $remotemodule = "authors";
my $remotedir = "id";

my $localabsrecent = File::Spec->catfile($rf->localroot,$recent);
my $remotebase = "$remotehost\::$remotemodule/$remotedir";

my $max_epoch_ever = 0;

my $rs = File::Rsync->new({
                           compress => 1,
                           'rsync-path' => '/usr/bin/rsync',
                          });
my %got_at;
ITERATION: while () {
  my $iteration_start = time;

  my($fh) = File::Temp->new(TEMPLATE => ".RECENT-XXXX",
                            DIR => $rf->localroot,
                            SUFFIX => "yaml",
                            UNLINK => 0,
                           );
  my($trecentfile) = $fh->filename;
  unless ($rs->exec(
                    src => File::Spec->catfile($remotebase,$recent),
                    dst => $trecentfile,
                   )) {
    warn sprintf "Warning: %s", $rs->err;
    sleep 5;
    next ITERATION;
  }
  my $mode = 0644;
  chmod $mode, $trecentfile;
  my($recent_data) = YAML::Syck::LoadFile($trecentfile);
  my @error;
 UPLOADITEM: for my $upload (reverse @$recent_data) {
    if ($upload->{type} eq "new"){
      my $must_get;
      if ($upload->{epoch} < $max_epoch_ever) {
        next UPLOADITEM;
      } elsif ($upload->{epoch} == $max_epoch_ever) {
        unless ($got_at{$upload->{path}}++) {
          $must_get++;
        }
      } else {
        $must_get++;
      }
      if ($must_get) {
        my $dst = File::Spec->catfile($rf->localroot,$upload->{path});
        my $doing = -e $dst ? "Syncing" : "Getting";
        warn "$doing $upload->{path}\n";
        mkpath dirname $dst;
        unless ($rs->exec(
                  src => "$remotebase/$upload->{path}",
                  dst => $dst,
                 )) {
          warn sprintf "Warning: %s", $rs->err;
          push @error, $rs->err;
          sleep 1;
          next UPLOADITEM;
        }
        $got_at{$upload->{path}} = $upload->{epoch};
      }
    } else {
      warn "Warning: only 'new' implemented";
    }
    $max_epoch_ever = $upload->{epoch} if $upload->{epoch} > $max_epoch_ever;
  }
  if (@error) {
    $max_epoch_ever = 0;
    %got_at = ();
  } else {
    rename $trecentfile, $localabsrecent; # keep this even when we write our own
    for my $k (keys %got_at) {
      delete $got_at{$k} if $got_at{$k} < $max_epoch_ever - 60*60*24*2;
    }
  }
  my $minimum_time_per_loop = 20;
  { local $| = 1; print "~"; }
  if (time - $iteration_start < $minimum_time_per_loop) {
    # last ITERATION;
    sleep $iteration_start + $minimum_time_per_loop - time;
  }
  { local $| = 1; print "."; }
}

print "\n";

__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
