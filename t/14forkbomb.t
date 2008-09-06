BEGIN {
    $|++;
    unless (@ARGV && shift(@ARGV) eq "--doit") {
        $|=1;
        print "1..0 # SKIP test only run when called with --doit\n";
        eval "require POSIX; 1" and POSIX::_exit(0);
        exit;
    }
}
use strict;
use lib "lib";
use CPAN;
my $i = shift;
die "# Stopping the bomb, saw arg $i" if $i && $i>=4;
my $pid = fork;
die "could not fork" unless defined $pid;
if ($pid){ # parent
    warn "# (harmless) forkbomb: $$ has forked $pid";
} else {
    sleep 1; # let the parent say goodbye first
    warn "# (harmless) forkbomb: in the child $$";
    exec $^X, "t/14forkbomb.t", "--doit", ++$i;
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
