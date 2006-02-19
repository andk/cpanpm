use Test::More tests => 2;
require CPAN;
{
    eval {CPAN::rtlpr()};
    like $@, qr/Unknown CPAN command/,q/AUTOLOAD rejects/;
}
{
    my $rdep = CPAN::Exception::RecursiveDependency->new([qw(foo bar baz foo)]);
    like $rdep, qr/foo.+=>.+bar.+=>.+baz.+=>.+foo/s;
}
# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
