use strict;
no warnings 'redefine';

=pod

Notes about coverage

2006-02-03 after rev. 517 we have this coverage

----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      20.1   10.2    7.9   37.0   37.9   16.7
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                63.6   40.0    0.0  100.0    0.1   55.3
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3   40.1   44.6
blib/lib/CPAN/HandleConfig.pm         61.6   47.5   32.1   88.2   21.6   54.6
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm                6.8    0.0    0.0   28.6    0.0    5.2
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.3   78.6
Total                                 25.6   13.9   15.5   45.2  100.0   22.0
----------------------------------- ------ ------ ------ ------ ------ ------

Admin.pm is kind of deprecated, but if we ever would like to test it,
we would issue C<! use CPAN::Admin> rather late in the testing which
would activate the override. C<reload cpan> would then switch back.



=cut

BEGIN {
    #chdir 't' if -d 't';
    unshift @INC, './lib';
    require Config;
    unless ($Config::Config{osname} eq "linux" or $ENV{CPAN_RUN_SHELL_TEST}) {
	print "1..0 # Skip: test is only validated on linux\n";
  warn "\n\n\a Skipping tests! If you want to run the test
  please set environment variable \$CPAN_RUN_SHELL_TEST to 1.\n
  Pls try it on your box and inform me if it works\n";
	exit 0;
    }
    eval { require Expect };
    # I consider it good-enough to have this test only where somebody
    # has Expect installed. I do not want to promote Expect to
    # everywhere.
    if ($@) {
	print "1..0 # Skip: no Expect\n";
	exit 0;
    }
}

use File::Copy qw(cp);
cp "t/CPAN/TestConfig.pm", "t/CPAN/MyConfig.pm"
    or die "Could not cp t/CPAN/TestConfig.pm over t/CPAN/MyConfig.pm: $!";

use Cwd;
my $cwd = Cwd::cwd;

sub read_myconfig () {
    open my $fh, "t/CPAN/MyConfig.pm" or die "Could not read t/CPAN/MyConfig.pm: $!";
    local $/;
    eval <$fh>;
}

my @prgs;
{
    local $/;
    @prgs = split /########.*/, <DATA>;
    close DATA;
}

use Test::More;
plan tests => scalar @prgs + 2;

read_myconfig;
is($CPAN::Config->{histsize},100,"histsize is 100");

my $exp = Expect->new;
my $prompt = "cpan>";
$exp->spawn(
            $^X,
            "-I$cwd/t",                 # get this test's own MyConfig
            "-Mblib",
            "-MCPAN::MyConfig",
            "-MCPAN",
            ($INC{"Devel/Cover.pm"} ? "-MDevel::Cover" : ()),
            # (@ARGV) ? "-d" : (), # force subtask into debug, maybe useful
            "-e",
            # "\$CPAN::Suppress_readline=1;shell('$prompt\n')",
            "shell('$prompt\n')",
           );
my $timeout = 6;
$exp->log_stdout(0);
$exp->notransfer(1);

# shamelessly stolen from Test::Builder
sub mydiag {
    my(@msgs) = @_;
    my $msg = join '', map { defined($_) ? $_ : 'undef' } @msgs;
    # Escape each line with a #.
    $msg =~ s/^/# /gm;
    # Stick a newline on the end if it needs it.
    $msg .= "\n" unless $msg =~ /\n\Z/;
    print $msg;
}

$exp->expect(
             $timeout,
             [ eof => sub { exit } ],
             [ timeout => sub {
                   my $self = $exp;
                   mydiag "+++timed out+++\n";
                   my $got = $self->clear_accum;
                   mydiag "GOT: $got\n";
                   if ($got =~ /lockfile/) {
		       mydiag "+++due to lockfile, proceeding+++\n";
                       $self->send("y\n");
                   } else {
		       mydiag "+++unknown reason+++\n";
                       mydiag "+++giving up this whole test+++\n";
                       exit;
                   }
                   Expect::exp_continue;
               }],
             '-re', "(?s:ReadLine support enabled.*".quotemeta($prompt).")"
            );

my $got = $exp->clear_accum;
mydiag "GOT: $got\n";
$timeout = 60;
$|=1;
for my $i (0..$#prgs){
    my $chunk = $prgs[$i];
    my($prog,$expected) = split(/~~like~~.*/, $chunk);
    unless (defined $expected) {
        ok(1,"empty test");
        next;
    }
    for ($prog,$expected) {
      s/^\s+//;
      s/\s+\z//;
    }
    mydiag "NEXT: $prog";
    my $sendprog = $prog;
    $sendprog =~ s/\\t/\t/g;
    $exp->send("$sendprog\n");
    $expected .= "(?s:.*$prompt)" unless $expected =~ /\(/;
    mydiag "EXPECT: $expected";
    $exp->expect(
                 $timeout,
                 [ eof => sub { exit } ],
                 [ timeout => sub {
                       my $got = $exp->clear_accum;
                       diag "timed out on i[$i]prog[$prog]
expected[$expected]\ngot[$got]\n\n";
                       exit;
                   } ],
                 '-re', $expected
                );
    my $got = $exp->clear_accum;
    mydiag "GOT: $got\n";
    ok(1, $prog||"\"\\n\"");
}

$exp->soft_close;

read_myconfig;
is($CPAN::Config->{histsize},101);

__END__
########
o conf build_cache
~~like~~
build_cache
########
o conf init
~~like~~
initialized(?s:.*manual.*configuration.*\])
########
nothanks
~~like~~
wrote
########
o conf histsize 101
~~like~~
.  histsize.+101
########
o conf commit
~~like~~
wrote
########
o conf histsize 102
~~like~~
.  histsize.+102
########
o conf defaults
~~like~~
########
o conf histsize
~~like~~
histsize.+101
########
o conf urllist
~~like~~
file:///.*CPAN
########
!print$ENV{HARNESS_PERL_SWITCHES},$/
~~like~~
########
rtlprnft
~~like~~
Unknown
########
m Fcntl
~~like~~
Defines fcntl
########
a JHI
~~like~~
Hietaniemi
########
h
~~like~~
(?s:make.*test.*install.*force.*notest.*reload)
########
o conf
~~like~~
(?s:commit.*build_cache.*cpan_home.*inhibit_startup_message.*urllist)
########
o conf help
~~like~~
(?s:commit.*defaults.*help.*init.*urllist)
########
o conf inhibit_\t
~~like~~
inhibit_startup_message
########
quit
~~like~~
(removed\.)
########

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
