BEGIN {
    $|++;
    local $^W;
    eval "qr/qr/";
    if ($@) {
	print "1..0 # Skip: no qr//\n";
	eval "require POSIX; 1" and POSIX::_exit(0);
    }
}
use Test::More tests => 3;
use File::Spec;
sub _f ($) {
    File::Spec->catfile(split /\//, shift);
}
use File::Copy qw(cp);
cp _f"t/CPAN/TestConfig.pm", _f"t/CPAN/MyConfig.pm"
    or die "Could not cp t/CPAN/TestConfig.pm over t/CPAN/MyConfig.pm: $!";
unshift @INC, "t";
require CPAN::MyConfig;
require CPAN;
{
    eval {CPAN::rtlpr()};
    like $@, qr/Unknown CPAN command/,q/AUTOLOAD rejects/;
}
{
    my $rdep = CPAN::Exception::RecursiveDependency->new([qw(foo bar baz foo)]);
    like $rdep, qr/foo.+=>.+bar.+=>.+baz.+=>.+foo/s;
}
{
    my $a = CPAN::Shell->expand("Module",
                                "CPAN::Test::Dummy::Perl5::Make"
                               )->distribution->author->as_string;
    like $a, qr/Andreas/;
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
