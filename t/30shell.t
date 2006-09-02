use strict;

use vars qw($HAVE_EXPECT $RUN_EXPECT $HAVE);
BEGIN {
    $|++;
    #chdir 't' if -d 't';
    unshift @INC, './lib';
    require Config;
    unless ($Config::Config{osname} eq "linux" or $ENV{CPAN_RUN_SHELL_TEST}) {
	print "1..0 # Skip: only validated on linux; maybe try env CPAN_RUN_SHELL_TEST=1\n";
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
END {
    unlink _f"t/dot-cpan/sources/authors/id/A/AN/ANDK/CHECKSUMS";
}
cp _f"t/CPAN/TestConfig.pm", _f"t/CPAN/MyConfig.pm"
    or die "Could not cp t/CPAN/TestConfig.pm over t/CPAN/MyConfig.pm: $!";
mkpath _d"t/dot-cpan/Bundle";
cp _f"t/CPAN/CpanTestDummies-1.55.pm",
    _f"t/dot-cpan/Bundle/CpanTestDummies.pm" or die
    "Could not cp t/CPAN/CpanTestDummies-1.55.pm over ".
    "t/dot-cpan/Bundle/CpanTestDummies.pm: $!";

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
                 Archive::Zip
                 Data::Dumper
                );

use Test::More;
plan tests => (
               scalar @prgs
               + 2                     # 2 histsize tests
               + 1                     # 1 RUN_EXPECT feedback
               + 1                     # 1 count keys for 'o conf init variable'
               # + scalar @modules
              );

sub mreq ($) {
    my $m = shift;
    eval "require $m; 1";
}

my $m;
for $m (@modules) {
    $HAVE->{$m}++ if mreq $m;
}
$HAVE->{"Term::ReadLine::Perl||Term::ReadLine::Gnu"}
    =
    $HAVE->{"Term::ReadLine::Perl"}
    || $HAVE->{"Term::ReadLine::Gnu"};
read_myconfig;
is($CPAN::Config->{histsize},100,"histsize is 100");

{
    require CPAN::HandleConfig;
    my @ociv_tests = map { /P:o conf init (\w+)/ && $1 } @prgs;
    my %ociv;
    @ociv{@ociv_tests} = ();
    my @kwnt = sort grep { not exists $ociv{$_} }
        grep { ! /(?:^urllist|_list|_hash)$/ }
            keys %CPAN::HandleConfig::keys;
    my $test_tuning = 0;
    if ($test_tuning) {
        ok(@kwnt==0,"key words not tested[@kwnt]");
        die if @kwnt;
    } else {
        ok(1,"Another dummy test");
    }
}

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

sub splitchunk ($) {
    my $ch = shift;
    my @s = split /(^[A-Z]:)/m, $ch;
    shift @s; # leading empty string
    for (my $i = 0; $i < @s; $i+=2) {
        $s[$i] =~ s/://;
    }
    @s;
}

TUPL: for my $i (0..$#prgs){
    my $chunk = $prgs[$i];
    my %h = splitchunk $chunk;
    my($prog,$expected,$req) = @h{qw(P E R)};
    unless (defined $expected or defined $prog) {
        ok(1,"empty test");
        next TUPL;
    }
    if ($req) {
        my @req = split " ", $req;
        my $r;
        for $r (@req) {
            if (not $HAVE->{$r}) {
                ok(1,"test skipped because $r missing");
                next TUPL;
            }
        }
    }
    for ($prog,$expected) {
        $_ = "" unless defined $_;
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
            print SYSTEM "# NEXT: $sendprog\n";
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
        $prog =~ s/^(\d)/...$1/;
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
    close SYSTEM;
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
rmtree _d"t/dot-cpan";

__END__
########
E:(?s:ReadLine support (enabled|suppressed|available).*?cpan[^>]*?>)
########
P:o conf build_cache
E:build_cache
########
P:o conf init
E:initialized(?s:.*?configure.as.much.as.possible.automatically.*?\])
########
P:yesplease
E:wrote
########
P:# o debug all
########
P:o conf histsize 101
E:.  histsize.+?101
########
P:o conf commit
E:wrote
########
P:o conf histsize 102
E:.  histsize.+?102
########
P:o conf defaults
########
P:o conf histsize
E:histsize.+?101
########
P:o conf urllist
E:file:///.*?CPAN
########
P:o conf init build_cache
E:(\])
########
P:100
E:
########
P:o conf init build_dir
E:(\])
########
P:foo
E:
########
P:o conf init bzip2
E:(\])
########
P:foo
E:
########
P:o conf init cache_metadata
E:(\])
########
P:y
E:
########
P:o conf init check_sigs
E:(\])
########
P:y
E:
########
P:o conf init cpan_home
E:(\])
########
P:/tmp/must_be_a_createable_absolute_path/../
E:
########
P:o conf init curl
E:(\])
########
P:foo
E:
########
P:o conf init gpg
E:(\])
########
P:foo
E:
########
P:o conf init gzip
E:(\])
########
P:foo
E:
########
P:o conf init lynx
E:(\])
########
P:foo
E:
########
P:o conf init make_arg
E:(\])
########
P:foo
E:
########
P:o conf init make_install_arg
E:(\])
########
P:foo
E:
########
P:o conf init make_install_make_command
E:(\])
########
P:foo
E:
########
P:o conf init makepl_arg
E:(\])
########
P:foo
E:
########
P:o conf init mbuild_arg
E:(\])
########
P:foo
E:
########
P:o conf init mbuild_install_arg
E:(\])
########
P:foo
E:
########
P:o conf init mbuild_install_build_command
E:(\])
########
P:foo
E:
########
P:o conf init mbuildpl_arg
E:(\])
########
P:foo
E:
########
P:o conf init ncftp
E:(\])
########
P:foo
E:
########
P:o conf init ncftpget
E:(\])
########
P:foo
E:
########
P:foo
E:
########
P:o conf init pager
E:(\])
########
P:foo
E:
########
P:o conf init prefer_installer
E:(\])
########
P:EUMM
E:
########
P:o conf init prerequisites_policy
E:(\])
########
P:ask
E:
########
P:o conf init scan_cache
E:(\])
########
P:atstart
E:
########
P:o conf init shell
E:(\])
########
P:foo
E:
########
P:o conf init show_upload_date
E:(\])
########
P:y
E:
########
P:o conf init tar
E:(\])
########
P:foo
E:
########
P:o conf init term_is_latin
E:(\])
########
P:n
E:
########
P:o conf init test_report
E:(\])
########
P:n
E:
########
P:o conf init unzip
E:(\])
########
P:foo
E:
########
P:o conf init wget
E:(\])
########
P:foo
E:
########
P:o conf init commandnumber_in_prompt
E:(\])
########
P:y
E:
########
P:o conf init ftp
E:(\])
########
P:foo
E:
########
P:o conf init make
E:(\])
########
P:foo
E:
########
P:o conf init ftp_passive
E:(\])
########
P:y
E:
########
P:o conf init ftp_proxy
E:(\])
########
P:y
E:
########
P:o conf init http_proxy
E:(\])
########
P:y
E:
########
P:o conf init no_proxy
E:(\])
########
P:y
E:
########
P:o conf defaults
########
P:!print$ENV{HARNESS_PERL_SWITCHES}||"",$/
E:
########
P:!print $INC{"CPAN/Config.pm"} || "NoCpAnCoNfIg",$/
E:NoCpAnCoNfIg
########
P:!print $INC{"CPAN/MyConfig.pm"},$/
E:CPAN/MyConfig.pm
########
P:rtlprnft
E:Unknown
########
P:o conf ftp ""
########
P:m Fcntl
E:Defines fcntl
########
P:a JHI
E:Hietaniemi
########
P:a ANDK JHI
E:(?s:Andreas.*?Hietaniemi.*?items found)
########
P:autobundle
E:Wrote bundle file
########
P:b
E:(?s:Bundle::CpanTestDummies.*?items found)
########
P:b
E:(?s:Bundle::Snapshot\S+\s+\(N/A\))
########
P:b Bundle::CpanTestDummies
E:\sCONTAINS.+?CPAN::Test::Dummy::Perl5::Make.+?CPAN::Test::Dummy::Perl5::Make::Zip
R:Archive::Zip
########
P:install ANDK/NotInChecksums-0.000.tar.gz
E:(?s:awry.*?yes)
R:Digest::SHA
########
P:n
R:Digest::SHA
########
P:d ANDK/CPAN-Test-Dummy-Perl5-Make-1.02.tar.gz
E:CONTAINSMODS\s+CPAN::Test::Dummy::Perl5::Make
########
P:d ANDK/CPAN-Test-Dummy-Perl5-Make-1.02.tar.gz
E:CPAN_USERID.*?ANDK.*?Andreas
########
P:ls ANDK
E:(?s:\d+\s+\d\d\d\d-\d\d-\d\d\sANDK/CPAN-Test-Dummy.*?\d+\s+\d\d\d\d-\d\d-\d\d\sANDK/Devel-Symdump)
########
P:ls ANDK/CPAN*
E:(?s:Text::Glob\s+loaded\s+ok.*?CPAN-Test-Dummy)
R:Text::Glob
########
P:force ls ANDK/CPAN*
E:(?s:CPAN-Test-Dummy)
R:Text::Glob
########
P:test CPAN::Test::Dummy::Perl5::Make
E:test\s+--\s+OK
########
P:test CPAN::Test::Dummy::Perl5::Build
E:test\s+--\s+OK
R:Module::Build
########
P:test CPAN::Test::Dummy::Perl5::Make::Zip
E:test\s+--\s+OK
R:Archive::Zip
########
P:failed
E:Nothing
########
P:test CPAN::Test::Dummy::Perl5::Build::Fails
E:test\s+--\s+NOT OK
R:Module::Build
########
P:dump CPAN::Test::Dummy::Perl5::Make
E:(?s:bless.+?('(ID|CPAN_FILE|CPAN_USERID|CPAN_VERSION)'.+?){4})
R:Data::Dumper
########
P:install CPAN::Test::Dummy::Perl5::Make::Failearly
E:(?s:Failed during this command.+?writemakefile NO)
########
P:test CPAN::Test::Dummy::Perl5::NotExists
E:Warning:
########
P:clean NOTEXISTS/Notxists-0.000.tar.gz
E:nothing done
########
P:failed
E:Test-Dummy-Perl5-Build-Fails.*?make_test NO
R:Module::Build
########
P:failed
E:Test-Dummy-Perl5-Make-Failearly.*?writemakefile NO
########
P:o conf commandnumber_in_prompt 1
########
P:o conf build_cache 0.1
E:build_cache
########
P:reload index
E:staleness
########
P:m /l/
E:(?s:Perl5.*?Fcntl)
########
P:i /l/
E:(?s:Dummies.*?Dummy.*?Perl5.*?Fcntl)
########
P:h
E:(?s:make.*?test.*?install.*?force.*?notest.*?reload)
########
P:o conf
E:(?s:commit.*?build_cache.*?cpan_home.*?inhibit_startup_message.*?urllist)
########
P:o conf prefer_installer EUMM
########
P:make CPAN::Test::Dummy::Perl5::BuildOrMake
E:(?s:Running make.*?Writing Makefile.*?make["']?\s+-- OK)
########
P:o conf prefer_installer MB
R:Module::Build
########
P:force get CPAN::Test::Dummy::Perl5::BuildOrMake
E:Removing previously used
R:Module::Build
########
P:make CPAN::Test::Dummy::Perl5::BuildOrMake
E:(?s:Running Build.*?Creating new.*?Build\s+-- OK)
R:Module::Build
########
P:test Bundle::CpanTestDummies
E:Test-Dummy-Perl5-Build-Fails-\S+\s+make_test\s+NO
R:Module::Build
########
P:get Bundle::CpanTestDummies
E:Is already unwrapped
########
P:notest make Bundle::CpanTestDummies
E:Has already been processed
########
P:clean Bundle::CpanTestDummies
E:Failed during this command
########
P:clean Bundle::CpanTestDummies
E:make clean already called once
########
P:r
E:(All modules are up to date|installed modules|Fcntl)
########
P:u /--/
E:No modules found for
########
P:m _NEXISTE_::_NEXISTE_
E:Defines nothing
########
P:m /_NEXISTE_/
E:Contact Author J. Cpantest Hietaniemi
########
P:notest
E:Pragma.*?method
########
P:o conf help
E:(?s:commit.*?defaults.*?help.*?init.*?urllist)
########
P:o conf inhibit_\t
E:inhibit_startup_message
R:Term::ReadLine::Perl||Term::ReadLine::Gnu
########
P:quit
E:(removed\.)
########

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
