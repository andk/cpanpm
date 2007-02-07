BEGIN {
    $|++;
    local $^W;
    eval "qr/qr/";
    if ($@) {
        $|=1;
	print "1..0 # Skip: no qr//\n";
	eval "require POSIX; 1" and POSIX::_exit(0);
    }
}
my $count;
use Test::More;
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
require CPAN::HandleConfig;
{
    eval {CPAN::rtlpr()};
    like $@, qr/Unknown CPAN command/,q/AUTOLOAD rejects/;
    BEGIN{$count++}
}
{
    my $rdep = CPAN::Exception::RecursiveDependency->new([qw(foo bar baz foo)]);
    like $rdep, qr/foo.+=>.+bar.+=>.+baz.+=>.+foo/s, "recursive dependency detected";
    BEGIN{$count++}
}
{
    my $a = CPAN::Shell->expand("Module",
                                "CPAN::Test::Dummy::Perl5::Make"
                               )->distribution->author->as_string;
    like $a, qr/Andreas/, "found Andreas in CPAN::Test::Dummy::Perl5::Make";
    BEGIN{$count++}
}
{
    no strict;
    {
        package S;
        for my $m (qw(myprint mydie mywarn mysleep)){
            *$m = sub {
                return;
            }
        }
    }
    $CPAN::Frontend = $CPAN::Frontend = "S";
    $_ = "Fcntl";
    my $m = CPAN::Shell->expand(Module => $_);
    $m->uptodate;
    is($_,"Fcntl","\$_ is properly localized");
    BEGIN{$count++}
}
{
    my @s;
    BEGIN{
        @s=(
            '"a"',
            '["a"]',
            '{a=>"b"}',
            '{"a;"=>"b"}',
            '"\\\\"',
           );
        $count+=@s;
    }
    for (0..$#s) {
        my $x = eval $s[$_];
        my $y = CPAN::HandleConfig->neatvalue($x);
        my $z = eval $y;
        is_deeply($z,$x,"s[$_]");
    }
}

BEGIN{plan tests => $count}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
