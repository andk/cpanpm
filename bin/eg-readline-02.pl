# currently works with perl-5.8.0@29163

use strict;
use AnyEvent;

BEGIN { $ENV{PERL_RL} = "gnu" }
use Term::ReadLine;

my $rl = new Term::ReadLine "cfshell";
my $w = AnyEvent->io (fh => $rl->IN,
                      poll => 'r',
                      cb => sub { $rl->callback_read_char },
                     );
$rl->callback_handler_install ("$ARGV[0]> ",
                               sub {
                                 $rl->add_history ($_[0]);
                               });
my $cv = AnyEvent->condvar;
$cv->wait;

__END__
