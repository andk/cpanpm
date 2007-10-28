#!/usr/bin/perl -w
use strict;

use warnings;
use CPAN::DistnameInfo;
use File::Basename qw(fileparse dirname);
use POE qw(Component::JobQueue Component::DebugShell);

use Time::HiRes qw(sleep);
use YAML::Syck;

use lib "/home/k/dproj/PAUSE/SVN/lib/";
use PAUSE; # loads File::Rsync::Mirror::Recentfile for now

POE::Component::JobQueue->spawn
    ( Alias         => 'passive',         # defaults to 'queuer'
      WorkerLimit   => 2,                 # defaults to 8
      Worker        => \&spawn_a_worker,  # code which will start a session
      Passive       =>
      {
       Prioritizer => \&job_comparer,    # defaults to sub { 1 } # FIFO
      },
    );

sub job_comparer { 1 }

sub spawn_a_worker {
  my ($postback, @job_params) = @_;     # same parameters as posted
  my $first = $job_params[0];
  POE::Session->create
        ( inline_states => {
                            _start => sub {
                              my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
                              print "sleeping 5\n";
                              sleep 5;
                              print "slept 5\n";
                            },
                            _stop => sub {},
                           },
          args          => [ $postback,     # $postback->(@results) to return
                             @job_params,   # parameters of this job
                           ],
        );
  print "firstpath[$first->{path}]firstperl[$first->{perl}]\n";
}

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
    $recent_events = [ grep {
      my $path = $_->{path};
      my $d = CPAN::DistnameInfo->new($path);
      my $dist = $d->dist;
      # warn "no dist for path[$path]" unless $dist;
      $dist ? !$seen{$dist}++ : "";
    } @$recent_events ];
  }
  $heap->{recent_events} = $recent_events;
  $heap->{have_read_recent_events_at} = time;
}


# different than in loop_... we allow only perls from otherperls here
# because we want no overlap
sub determine_perls {
  my($basedir,$otherperls) = @_;
  my @perls;
  if (open my $fh2, $otherperls) {
    while (<$fh2>) {
      chomp;
      s/#.*//; # remove comments
      next if /^\s*$/; # remove empty/white lines
      next unless -x $_;
      push @perls, $_;
    }
  } else {
    opendir my $dh, $basedir or die;
    @perls = sort grep { /^megainstall\..*\.d$/ } readdir $dh;
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
  print "rest[$rest]\n";
  $kernel->post( 'passive',   # post to 'passive' alias
                 'enqueue',   # 'enqueue' a job
                 'postback',  # which of our states is notified when it's done
                 $first, # job parameters
               );
  $kernel->delay('harvest_from_queue', 0.2);
}

sub postback {
  require YAML::Syck; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . YAML::Syck::Dump(\@_); # XXX
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
                                       postback => \&postback,
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

Next steps are POE::Component::JobQueue and a status file that
prevents duplicate work and filters items that have a higher version
number counterpart. It's OK when the job does nothing but "echo hello
world" for this next step but it should do it with a JobQueue.

Recap: POE:C:CP:YS is based on Barbie CP:YS

