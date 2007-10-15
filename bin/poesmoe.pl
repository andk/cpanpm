#!/usr/bin/perl -w
use strict;

use warnings;
use CPAN::DistnameInfo;
use File::Basename qw(fileparse dirname);
use POE;
use POE::Component::DebugShell;
use Time::HiRes qw(sleep);
use YAML::Syck;

use lib "/home/k/dproj/PAUSE/SVN/lib/";
use PAUSE; # loads File::Rsync::Mirror::Recentfile for now

sub work_handler_start {
  my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
  $heap->{rf} = File::Rsync::Mirror::Recentfile->new(
                                                     canonize => "naive_path_normalize",
                                                     localroot => "/home/ftp/pub/PAUSE/authors/id/",
                                                     intervals => [qw(2d)],
                                                    );
  $heap->{otherperls} = "$0.otherperls";
  my $bbname = fileparse($0,qr{\.pl});
  $heap->{historyfile} = "$ENV{HOME}/.cpan/$bbname.history.yml";
  # planning to $x{join"|",$dist,$perl} = join"|",time,$state;
  # where state in started, "ret[$ret]";
  $heap->{rx} = qr!(?i:\.(tar.gz|tar.bz2|zip|tgz|tbz))$!;

  $heap->{basedir} = "/home/sand/CPAN-SVN/logs";
  $kernel->yield('do_read_recent');
  $kernel->yield('increment');
}

sub sub_read_recent_events {
  my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
  my $since_last_time = time - ($heap->{have_read_recent_events_at}||0);
  if ($since_last_time < 15) {
    my $delay = int(15 - $since_last_time + 1);
    print "Delaying $delay seconds\n";
    $kernel->delay("do_read_recent", $delay);
    return;
  } else {
    $kernel->yield("increment");
  }
  my($rf) = $heap->{rf};
  my($rx) = $heap->{rx};
  my $recent_events = $rf->recent_events;
  $recent_events = [ grep { $_->{path} =~ $rx } @$recent_events ];
  {
    my %seen;
    $recent_events = [ grep { my $d = CPAN::DistnameInfo->new($_->{path});
                              !$seen{$d->dist}++
                            } @$recent_events ];
  }
  $heap->{recent_events} = $recent_events;
  $heap->{have_read_recent_events_at} = time;
}

sub determine_perls {
  my($basedir,$otherperls) = @_;
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
  \@perls;
}

sub work_handler_inc {
  my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
  my $cnt = $heap->{count}++;
  print "Session ", $session->ID, " counted to $cnt.\n";
  if (!$heap->{raw_queue}
      || $cnt > $#{$heap->{raw_queue}}
     ) {
    my $raw_queue = $heap->{raw_queue} = [];
    my $perls;
    my $recent_events = $heap->{recent_events};
  UPLOADITEM: for my $upload (reverse @$recent_events) {
      next unless $upload->{path} =~ $heap->{rx};
      next unless $upload->{type} eq "new";
      $perls ||= determine_perls($heap->{basedir},$heap->{otherperls});
    PERL: for my $perl (@$perls) {
        push @$raw_queue, { perl => $perl, path => $upload->{path}};
      }
    }
  }
  if ($cnt <= $#{$heap->{raw_queue}}) {
    print "cnt[$cnt]path[$heap->{raw_queue}[$cnt]{path}]perl[$heap->{raw_queue}[$cnt]{perl}]\n";
    $kernel->delay('increment', 0.1);
    $kernel->yield('harvest_from_queue');
  } else {
    $heap->{count} = 0;
    $kernel->yield('do_read_recent');
  }
}

sub harvest_from_queue {
  my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
  my $first = shift @{$heap->{raw_queue}} or return;
  my $rest = @{$heap->{raw_queue}};
  print "rest[$rest]firstpath[$first->{path}]firstperl[$first->{perl}]\n";
  $kernel->delay('harvest_from_queue', 0.2);
}

sub work_handler_stop {
  print "Session ", $_[SESSION]->ID, " has stopped.\n";
}

POE::Session->create(
                     inline_states => {
                                       _start    => \&work_handler_start,
                                       increment => \&work_handler_inc,
                                       do_read_recent => \&sub_read_recent_events,
                                       harvest_from_queue => \&harvest_from_queue,
                                       _stop     => \&work_handler_stop,
                                      }
                    );

# POE::Component::DebugShell->spawn();

POE::Kernel->run();
exit;

__END__


=head1 

The result shall do exactly the same as loop_over_recentfile but with
different perls. The three important perls run over there, the
rest runs here. Different conf and run files, separate console.

In the zeroeth approximation we call jobs that run "echo" and pass
their output on to STDOUT. They only say what they would do. So this
approximation only needs a different run file, not different perls.

Faszinating is that POE programs need no locks, they simply delegate
some work to an eventhandler.

The simple mechanism that is used so far with $max_epoch_worked_on is
good enough for sending jobs to the queue but in the queue itself we
must take more precautions to avoid duplicate work. In other words:
It's probably OK to stuff everything potentially interesting into a
queue and let the queue decide if the thing is really still of
interest. We must protect against what happens when we get killed and
must restart. We need not protect against a concurrent run of this
program. It's not about locking, just about delaying decisions until
they need to be reached. But still: if a job has already been done in
a previous run we should not stuff it into a queue again ever. And
here is why we need to decide in the very last moment again: our
policy is that if Foo-3.14 is uploaded we won't test Foo-3.13 at all.
So we must delay the ultimate decision to the last moment. An earlier
decision is just a luxury. And we can implement luxury later.
