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
use strict;
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
    like $rdep, qr/foo.+=>.+bar.+=>.+baz.+=>.+foo/s, "circular dependency";
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
{
    eval { require Kwalify };
    my $this_block_count;
    BEGIN { $count += $this_block_count = 2; }
    if ($@) {
        for (1..$this_block_count) {
            ok(1);
        }
    } else {
        require CPAN::Kwalify;
        my $data = {
                    "match" => {
                                "distribution" => "^(ABW|ADAMK)/Template-Toolkit-2.16"
                               },
                    "pl" => {
                             "args" => [
                                        "TT_EXTRAS=no"
                                       ],
                             "expect" => [
                                          "Do you want to build the XS Stash module",
                                          "n\n",
                                          "Do you want to install these components",
                                          "n\n",
                                          "Installation directory",
                                          "\n",
                                          "URL base for TT2 images",
                                          "\n",
                                         ],
                             barth => '1984',
                            },
                   };
        eval {CPAN::Kwalify::_validate("distroprefs",
                                       $data,
                                       _f("t/12cpan.t"),
                                       0)};
        ok($@,"no kwalify [$@]");
        delete $data->{pl}{barth};
        CPAN::Kwalify::_clean_cache();
        eval {CPAN::Kwalify::_validate("distroprefs",
                                       $data,
                                       _f("t/12cpan.t"),
                                       0)};
        ok(!$@,"kwalify ok");
    }
}

BEGIN{plan tests => $count}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
