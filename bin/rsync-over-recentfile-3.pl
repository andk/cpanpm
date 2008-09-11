#!/usr/bin/perl

=pod

Q1: sorted by epoch? Who has to sort when how often?

A11 (wrong): nobody! The mechanism is "event" based and the array is only
running push and shift (and grep). It is a journal (that throws memory
away based on an interval) and is itself NOT rsynced but in fact (?)
rewritten by every slave.

A12: usually nobody because the normal flow of things just sort
everything in the right slots. But in case somebody breaks the rules,
she has to sort accordingly and set a dirtymark flag.

Q2: or we do not ever promise that the timestamps are sorted or mirror
the sequence of events or we make them floating point numbers so they
become uniq and can be treated as hash keys [this I like!]). Please
keep in mind that we must be able to help customers who have
6000000000 files.

A21: yes, we promise the timestamps are sorted. They are floats and
keeping them sorted and uniq should be doable without too complicated
algorithms. But doing all this with a database instead of in-memory is
currently not our plan.

Q3: Interesting/Funny is the idea that dependents fetch files from
each other.

A31: yes

Q4: So the loop below says it wants to last at least 20 seconds but it
may take longer when there are many files to transfer. What needs to
be changed to make sure we refresh our copy of the recentfile when
some time has gone by?

A41: The rf object needs to return after every chunk, it must know when
it has covered the recentfile, if must know which intervals it has
covered and it must be able to merge intervals based on the
recent_events array. And the caller must get some info about these
states.

Q5: the refetching of the recentfile can either be done within the
mirror command or by the caller. There seems to be a difference
between the principal and the others. Only when the principal changes,
others can also change, so others should not waste time with
refreshing.

=cut

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;
use Getopt::Long qw(GetOptions);
use List::Util qw(min);
use Time::HiRes qw(sleep);

use lib "/home/k/sources/rersyncrecent/lib/";
require File::Rsync::Mirror::Recent;

our %Opt;
GetOptions(\%Opt,
           "verbose!",
          ) or die;

my %reached;
ITERATION: while () {
  my $iteration_start = time;

  for my $tuple ([authors => "6h"],[modules => "1h"]) {
    my($rmodule,$interval) = @$tuple;
    my $rf = File::Rsync::Mirror::Recentfile->new
        (
         canonize => "naive_path_normalize",
         filenameroot => "RECENT",
         ignore_link_stat_errors => 1,
         interval => $interval,
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
  for my $k (keys %reached) {
    next if $k =~ /T/;
    $reached{$k . "T"} = scalar localtime $reached{$k};
  }
  require YAML::Syck;
  print STDERR "Line " . __LINE__
      . ", File: " . __FILE__
          . "\n"
              . YAML::Syck::Dump(\%reached);

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
