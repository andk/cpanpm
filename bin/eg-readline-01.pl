# currently works neither with perl-5.8.0@29163 nor 29243 but has
# worked recently

# Now, after a 'stty sane' again works with 29163 and 29243

use strict;

use AnyEvent;

my $cv = AnyEvent->condvar;

my $io_watcher = AnyEvent->io (fh => \*STDIN,
                               poll => 'r',
                               cb => sub {
                                 warn "io event <$_[0]>\n";   # will always output <r>
                                 chomp (my $input = <STDIN>); # read a line
                                 warn "read: $input\n";       # output what has been read
                                 $cv->broadcast if $input =~ /^q/i; # quit program if /^q/i
                               });

my $time_watcher; # can only be used once

sub new_timer {
  $time_watcher = AnyEvent->timer (after => 2,
                                   cb => sub {
                                     warn "timeout\n"; # print 'timeout' about every second
                                     &new_timer; # and restart the time
                                   });
}

new_timer; # create first timer

$cv->wait; # wait until user enters /^q/i
