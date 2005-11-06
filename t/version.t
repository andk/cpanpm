# test if our own version numbers meet expectations

my @m = qw(CPAN CPAN::Admin CPAN::FirstTime CPAN::Nox CPAN::Version);

use Test::More;
plan(tests => scalar @m);

for my $m (@m) {
  eval "require $m";
  ok($m->VERSION >= 1.76, sprintf "%20s: %s", $m, $m->VERSION);
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
