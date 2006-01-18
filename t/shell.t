use strict;
no warnings 'redefine';


BEGIN {
    chdir 't' if -d 't';
    unshift @INC, '../lib';
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
cp "CPAN/TestConfig.pm", "CPAN/MyConfig.pm"
    or die "Could not cp t/CPAN/TestConfig.pm over t/CPAN/MyConfig.pm: $!";

use Cwd;
my $cwd = Cwd::cwd;

sub read_myconfig () {
    open my $fh, "CPAN/MyConfig.pm" or die "Could not read t/CPAN/MyConfig.pm: $!";
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
my $prompt = "cpan> ";
$exp->spawn(
            $^X,
            "-I$cwd",                 # get this test's own MyConfig
            "-I../lib",
            "-MCPAN::MyConfig",
            "-MCPAN",
            # (@ARGV) ? "-d" : (), # force subtask into debug, maybe useful
            "-e",
            "\$CPAN::Suppress_readline=1;shell('$prompt\n')",
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
             '-re', $prompt
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
    $exp->send("$prog\n");
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
quit
~~like~~
(removed\.)
########

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
