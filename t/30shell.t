use strict;

=pod

Notes about coverage

2006-02-03 after rev. 517 we have this coverage:
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

After rev. 523:
----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      26.7   15.6   10.4   42.6    4.2   22.5
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                63.6   40.0    0.0  100.0    0.1   55.3
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3   61.8   44.6
blib/lib/CPAN/HandleConfig.pm         61.6   47.5   32.1   88.2   33.4   54.6
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm               17.6    6.6    0.0   50.0    0.1   14.8
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.4   78.6
Total                                 31.2   18.5   17.1   50.4  100.0   26.8
----------------------------------- ------ ------ ------ ------ ------ ------

The time for the CPAN.pm tests is down because we're now using the
local, test-specific index files. Next thing to do: upload the demo
distro so that we can add a signed CHECKSUMS file.

After 525:
----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      41.0   26.3   21.5   57.8   44.1   35.4
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                63.6   40.0    0.0  100.0    0.1   55.3
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3   35.8   44.6
blib/lib/CPAN/HandleConfig.pm         61.6   47.5   32.1   88.2   19.3   54.6
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm               36.9   18.9   22.2   71.4    0.4   31.8
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.3   78.6
Total                                 43.1   27.5   24.9   63.0  100.0   37.4
----------------------------------- ------ ------ ------ ------ ------ ------

All sub values over 50%!

After 527:
----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      43.6   28.6   22.2   60.4   44.3   37.8
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                63.6   40.0    0.0  100.0    0.0   55.3
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3   35.7   44.6
blib/lib/CPAN/HandleConfig.pm         61.6   47.5   32.1   88.2   19.3   54.6
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm               36.9   18.9   22.2   71.4    0.4   31.8
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.3   78.6
Total                                 45.1   29.3   25.4   65.1  100.0   39.3
----------------------------------- ------ ------ ------ ------ ------ ------

After 553:
----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      45.9   30.9   25.3   63.4   79.1   40.2
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                63.6   40.0    0.0  100.0    0.0   55.3
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3   13.3   44.6
blib/lib/CPAN/HandleConfig.pm         61.6   47.5   32.1   88.2    7.2   54.6
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm               36.9   18.9   22.2   71.4    0.3   31.8
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.1   78.6
Total                                 46.9   31.2   27.5   67.4  100.0   41.1
----------------------------------- ------ ------ ------ ------ ------ ------

Time goes up now that we have 3 distros and the other values rise only slowly.

After 590 (bleadperl@27154):
---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm               50.4   35.4   30.8   69.4   47.7   84.8   44.9
blib/lib/CPAN/Admin.pm         12.9    0.0    0.0   62.5    0.0    0.0   11.7
blib/lib/CPAN/Debug.pm         63.6   40.0    0.0  100.0    0.0    0.0   53.8
blib/lib/CPAN/FirstTime.pm     55.6   33.0   27.8   79.3    n/a    9.7   44.6
.../lib/CPAN/HandleConfig.pm   60.6   45.2   32.0   88.2    0.0    5.2   52.2
blib/lib/CPAN/Nox.pm          100.0   50.0    n/a  100.0    n/a    0.0   95.0
blib/lib/CPAN/Tarzip.pm        46.6   25.5   22.2   78.6    0.0    0.3   39.2
blib/lib/CPAN/Version.pm       83.3   54.5   84.0  100.0    0.0    0.0   74.3
Total                          50.8   34.9   31.3   72.4   34.8  100.0   44.9
---------------------------- ------ ------ ------ ------ ------ ------ ------

Relevant patches: added the zip and the failearly distro, removing
unused code, low hanging fruits

After 597:
----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      50.9   36.1   32.7   70.7   88.5   45.6
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                63.6   40.0    0.0  100.0    0.0   55.3
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3    7.1   44.6
blib/lib/CPAN/HandleConfig.pm         60.6   45.2   32.0   88.2    3.9   53.5
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm               40.3   20.8   22.2   78.6    0.4   34.8
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.1   78.6
Total                                 50.9   35.3   32.6   73.5  100.0   45.4
----------------------------------- ------ ------ ------ ------ ------ ------

added the BuildOrMake distro

After 628
----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      52.2   37.0   32.8   71.4   89.7   46.6
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                63.6   40.0    0.0  100.0    0.0   55.3
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3    6.4   44.6
blib/lib/CPAN/HandleConfig.pm         60.6   45.2   32.0   88.2    3.4   53.5
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm               40.3   20.8   22.2   78.6    0.4   34.8
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.0   78.6
Total                                 51.9   36.1   32.7   74.0  100.0   46.2
----------------------------------- ------ ------ ------ ------ ------ ------

added a Bundle to the "Make" testdistro

After 636
----------------------------------- ------ ------ ------ ------ ------ ------
File                                  stmt   bran   cond    sub   time  total
----------------------------------- ------ ------ ------ ------ ------ ------
blib/lib/CPAN.pm                      53.9   38.0   33.3   73.3   89.8   48.0
blib/lib/CPAN/Admin.pm                12.9    0.0    0.0   62.5    0.0   11.8
blib/lib/CPAN/Debug.pm                68.2   40.0    0.0  100.0    0.0   57.9
blib/lib/CPAN/FirstTime.pm            55.6   33.0   27.8   79.3    6.3   44.6
blib/lib/CPAN/HandleConfig.pm         60.6   45.2   32.0   88.2    3.4   53.5
blib/lib/CPAN/Nox.pm                 100.0   50.0    n/a  100.0    0.0   95.0
blib/lib/CPAN/Tarzip.pm               40.3   20.8   22.2   78.6    0.4   34.8
blib/lib/CPAN/Version.pm              83.3   54.5   84.0  100.0    0.0   78.6
Total                                 53.3   36.8   33.0   75.5  100.0   47.2
----------------------------------- ------ ------ ------ ------ ------ ------


=cut

use vars qw($HAVE_EXPECT $RUN_EXPECT);
BEGIN {
    $|++;
    #chdir 't' if -d 't';
    unshift @INC, './lib';
    require Config;
    unless ($Config::Config{osname} eq "linux" or $ENV{CPAN_RUN_SHELL_TEST}) {
	print "1..0 # Skip: only validated on linux; maybe try env CPAN_RUN_SHELL_TEST=1\n";

#  warn "\n\n\a Skipping tests! If you want to run the test
#  please set environment variable \$CPAN_RUN_SHELL_TEST to 1.\n
#  Pls try it on your box and inform me if it works\n";

	print "1..0 # Skip: no linux\n";
	eval "require POSIX; 1" and POSIX::_exit(0);
    }
    eval { require Expect };
    if ($@) {
        unless ($ENV{CPAN_RUN_SHELL_TEST}) {
            print "1..0 # Skip: no Expect, maybe try env CPAN_RUN_SHELL_TEST=1\n";
            eval "require POSIX; 1" and POSIX::_exit(0);
        }
    } else {
        $HAVE_EXPECT = 1;
    }
}

use File::Spec;

sub _f ($) {File::Spec->catfile(split /\//, shift);}
sub _d ($) {File::Spec->catdir(split /\//, shift);}
use File::Path qw(rmtree mkpath);
rmtree _d"t/dot-cpan/sources";
rmtree _d"t/dot-cpan/build";
unlink _f"t/dot-cpan/Metadata";
unlink _f"t/dot-cpan/.lock";
mkpath _d"t/dot-cpan/sources/authors/id/A/AN/ANDK";

use File::Copy qw(cp);
cp _f"t/CPAN/authors/id/A/AN/ANDK/CHECKSUMS\@588",
    _f"t/dot-cpan/sources/authors/id/A/AN/ANDK/CHECKSUMS"
    or die "Could not cp t/CPAN/authors/id/A/AN/ANDK/CHECKSUMS\@588 ".
    "over t/dot-cpan/sources/authors/id/A/AN/ANDK/CHECKSUMS: $!";
cp _f"t/CPAN/TestConfig.pm", _f"t/CPAN/MyConfig.pm"
    or die "Could not cp t/CPAN/TestConfig.pm over t/CPAN/MyConfig.pm: $!";
cp _f"t/dot-cpan/Bundle/CpanTestDummies-1.55.pm",
    _f"t/dot-cpan/Bundle/CpanTestDummies.pm" or die
    "Could not cp t/dot-cpan/Bundle/CpanTestDummies-1.55.pm over ".
    "t/dot-cpan/Bundle/CpanTestDummies-1.55.pm: $!";

use Cwd;
my $cwd = Cwd::cwd;

sub read_myconfig () {
    local *FH;
    open *FH, _f"t/CPAN/MyConfig.pm" or die "Could not read t/CPAN/MyConfig.pm: $!";
    local $/;
    eval <FH>;
}

my @prgs;
{
    local $/;
    @prgs = split /########.*/, <DATA>;
    close DATA;
}
my @modules = qw(
                 Digest::SHA
                 Term::ReadKey
                 Term::ReadLine
                 Text::Glob
                 Module::Build
                );

use Test::More;
plan tests => (
               scalar @prgs
               + 2                     # 2 histsize tests
               + 1                     # 1 RUN_EXPECT feedback
               + scalar @modules
              );

for my $m (@modules) {
    use_ok($m);
}
read_myconfig;
is($CPAN::Config->{histsize},100,"histsize is 100");

my $prompt = "cpan>";
my $prompt_re = "cpan[^>]*?>"; # note: replicated in DATA!
my $t = File::Spec->catfile($cwd,"t");
my $timeout = 60;

my @system = (
              $^X,
              "-I$t",                 # get this test's own MyConfig
              "-Mblib",
              "-MCPAN::MyConfig",
              "-MCPAN",
              ($INC{"Devel/Cover.pm"} ? "-MDevel::Cover" : ()),
              # (@ARGV) ? "-d" : (), # force subtask into debug, maybe useful
              "-e",
              # "\$CPAN::Suppress_readline=1;shell('$prompt\n')",
              "\@CPAN::Defaultsites = (); shell",
             );

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

$|=1;
my $expo;
my @PAIRS;
$RUN_EXPECT = $HAVE_EXPECT || 0;
ok(1,"RUN_EXPECT[$RUN_EXPECT]");
if ($RUN_EXPECT) {
    $expo = Expect->new;
    $expo->spawn(@system);
    $expo->log_stdout(0);
    $expo->notransfer(1);
} else {
    my $system = join(" ", map { "\"$_\"" } @system)." > test.out";
    warn "# DEBUG: system[$system]";
    open SYSTEM, "| $system" or die;
}

PAIR: for my $i (0..$#prgs){
    my $chunk = $prgs[$i];
    my($prog,$expected) = split(/~~like~~.*/, $chunk);
    unless (defined $expected) {
        ok(1,"empty test");
        next PAIR;
    }
    for ($prog,$expected) {
      s/^\s+//;
      s/\s+\z//;
    }
    if ($prog) {
        my $sendprog = $prog;
        $sendprog =~ s/\\t/\t/g;
        if ($RUN_EXPECT) {
            mydiag "NEXT: $prog";
            $expo->send("$sendprog\n");
        } else {
            print SYSTEM "$sendprog\n";
        }
    }
    $expected .= "(?s:.*?$prompt_re)" unless $expected =~ /\(/;
    if ($RUN_EXPECT) {
        mydiag "EXPECT: $expected";
        $expo->expect(
                      $timeout,
                      [ eof => sub {
                            my $got = $expo->clear_accum;
                            diag "EOF on i[$i]prog[$prog]
expected[$expected]\ngot[$got]\n\n";
                            exit;
                        } ],
                      [ timeout => sub {
                            my $got = $expo->clear_accum;
                            diag "timed out on i[$i]prog[$prog]
expected[$expected]\ngot[$got]\n\n";
                            exit;
                        } ],
                      '-re', $expected
                     );
        my $got = $expo->clear_accum;
        mydiag "GOT: $got\n";
        ok(1, $prog||"\"\\n\"");
    } else {
        $expected = "" if $prog =~ /\t/;
        push @PAIRS, [$prog,$expected];
    }
}
if ($RUN_EXPECT) {
    $expo->soft_close;
} else {
    close SYSTEM or die "Could not close SYSTEM filehandle: $!";
    open SYSTEM, "test.out" or die "Could not open test.out for reading: $!";
    local $/;
    my $got = <SYSTEM>;
    my $pair;
    for $pair (@PAIRS) {
        my($prog,$expected) = @$pair;
        mydiag "EXPECT: $expected";
        $got =~ /(\G.*?$expected)/sgc or die "Failed on prog[$prog]expected[$expected]";
        mydiag "GOT: $1\n";
        ok(1, $prog||"\"\\n\"");
    }
}

read_myconfig;
is($CPAN::Config->{histsize},101);

__END__
########
~~like~~
(?s:ReadLine support (enabled|suppressed).*?cpan[^>]*?>)
########
o conf build_cache
~~like~~
build_cache
########
o conf init
~~like~~
initialized(?s:.*?manual.*?configuration.*?\])
########
nothanks
~~like~~
wrote
########
# o debug all
~~like~~
########
o conf histsize 101
~~like~~
.  histsize.+?101
########
o conf commit
~~like~~
wrote
########
o conf histsize 102
~~like~~
.  histsize.+?102
########
o conf defaults
~~like~~
########
o conf histsize
~~like~~
histsize.+?101
########
o conf urllist
~~like~~
file:///.*?CPAN
########
!print$ENV{HARNESS_PERL_SWITCHES}||"",$/
~~like~~
########
!print $INC{"CPAN/Config.pm"} || "NoCpAnCoNfIg",$/
~~like~~
NoCpAnCoNfIg
########
!print $INC{"CPAN/MyConfig.pm"},$/
~~like~~
CPAN/MyConfig.pm
########
rtlprnft
~~like~~
Unknown
########
o conf ftp ""
~~like~~
########
m Fcntl
~~like~~
Defines fcntl
########
a JHI
~~like~~
Hietaniemi
########
a ANDK JHI
~~like~~
(?s:Andreas.*?Hietaniemi.*?items found)
########
autobundle
~~like~~
Wrote bundle file
########
b
~~like~~
(?s:Bundle::CpanTestDummies.*?items found)
########
b Bundle::CpanTestDummies
~~like~~
\sCONTAINS.+?CPAN::Test::Dummy::Perl5::Make.+?CPAN::Test::Dummy::Perl5::Make::Zip
########
install ANDK/NotInChecksums-0.000.tar.gz
~~like~~
(?s:awry.*?yes)
########
n
~~like~~
########
d ANDK/CPAN-Test-Dummy-Perl5-Make-1.02.tar.gz
~~like~~
CONTAINSMODS\s+CPAN::Test::Dummy::Perl5::Make
########
d ANDK/CPAN-Test-Dummy-Perl5-Make-1.02.tar.gz
~~like~~
CPAN_USERID.*?ANDK.*?Andreas
########
ls ANDK
~~like~~
(?s:\d+\s+\d\d\d\d-\d\d-\d\d\sANDK/CPAN-Test-Dummy.*?\d+\s+\d\d\d\d-\d\d-\d\d\sANDK/Devel-Symdump)
########
ls ANDK/CPAN*
~~like~~
(?s:Text::Glob\s+loaded\s+ok.*?CPAN-Test-Dummy)
########
force ls ANDK/CPAN*
~~like~~
(?s:CPAN-Test-Dummy)
########
test CPAN::Test::Dummy::Perl5::Make
~~like~~
test\s+--\s+OK
########
test CPAN::Test::Dummy::Perl5::Build
~~like~~
test\s+--\s+OK
########
test CPAN::Test::Dummy::Perl5::Make::Zip
~~like~~
test\s+--\s+OK
########
failed
~~like~~
Nothing
########
test CPAN::Test::Dummy::Perl5::Build::Fails
~~like~~
test\s+--\s+NOT OK
########
dump CPAN::Test::Dummy::Perl5::Make
~~like~~
(?s:bless.+?('(ID|CPAN_FILE|CPAN_USERID|CPAN_VERSION)'.+?){4})
########
install CPAN::Test::Dummy::Perl5::Make::Failearly
~~like~~
(?s:Failed during this command.+?writemakefile NO)
########
test CPAN::Test::Dummy::Perl5::NotExists
~~like~~
Warning:
########
clean NOTEXISTS/Notxists-0.000.tar.gz
~~like~~
nothing done
########
failed
~~like~~
Test-Dummy-Perl5-Build-Fails.*?make_test NO
########
failed
~~like~~
Test-Dummy-Perl5-Make-Failearly.*?writemakefile NO
########
o conf commandnumber_in_prompt 1
~~like~~
########
o conf build_cache 0.1
~~like~~
build_cache
########
reload index
~~like~~
staleness
########
m /l/
~~like~~
(?s:Perl5.*?Fcntl)
########
i /l/
~~like~~
(?s:Dummies.*?Dummy.*?Perl5.*?Fcntl)
########
h
~~like~~
(?s:make.*?test.*?install.*?force.*?notest.*?reload)
########
o conf
~~like~~
(?s:commit.*?build_cache.*?cpan_home.*?inhibit_startup_message.*?urllist)
########
o conf prefer_installer EUMM
~~like~~
########
make CPAN::Test::Dummy::Perl5::BuildOrMake
~~like~~
(?s:Running make.*?Writing Makefile.*?make\s+-- OK)
########
o conf prefer_installer MB
~~like~~
########
force get CPAN::Test::Dummy::Perl5::BuildOrMake
~~like~~
Removing previously used
########
make CPAN::Test::Dummy::Perl5::BuildOrMake
~~like~~
(?s:Running Build.*?Creating new.*?Build\s+-- OK)
########
test Bundle::CpanTestDummies
~~like~~
Test-Dummy-Perl5-Build-Fails-\S+\s+make_test\s+NO
########
r
~~like~~
(All modules are up to date|installed modules|Fcntl)
########
u /--/
~~like~~
No modules found for
########
notest
~~like~~
Pragma.*?method
########
o conf help
~~like~~
(?s:commit.*?defaults.*?help.*?init.*?urllist)
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
