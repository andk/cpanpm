use strict;

# there's POD at the very end of this file

use vars qw($RUN_EXPECT $HAVE);
BEGIN {
    $|++;
    #chdir 't' if -d 't';
    unshift @INC, './lib';
    eval { require Expect };
    if ($@) {
        unless ($ENV{CPAN_RUN_SHELL_TEST_WITHOUT_EXPECT}) {
            print "1..0 # SKIP no Expect, maybe try env CPAN_RUN_SHELL_TEST_WITHOUT_EXPECT=1\n";
            eval "require POSIX; 1" and POSIX::_exit(0);
        }
    }
    eval { require YAML };
    if ($YAML::VERSION && $YAML::VERSION < 0.60) {
        print "1..0 # SKIP YAML too old for this test\n";
        eval "require POSIX; 1" and POSIX::_exit(0);
    }
  TABU: for my $tabu (qw(
                         CPAN::Test::Dummy::Perl5::Make
                         CPAN::Test::Dummy::Perl5::Make::ConfReq
                         CPAN::Test::Dummy::Perl5::Build::Fails
                         CPAN::Test::Dummy::Perl5::Make::CircDepeOne
                         CPAN::Test::Dummy::Perl5::Make::CircDepeTwo
                         CPAN::Test::Dummy::Perl5::Make::CircDepeThree
                         CPAN::Test::Dummy::Perl5::Make::Features
                         CPAN::Test::Dummy::Perl5::Make::UnsatPrereq
                        )) {
        my $f = $tabu;
        $f =~ s|::|/|g;
        $f .= ".pm";
        if (eval qq{require $tabu; 1}) {
            my $exit_message = "Found module '$tabu' installed at $INC{$f}. Cannot run this test.";
            print "1..0 # SKIP $exit_message\n";
            eval "require POSIX; 1" and POSIX::_exit(0);
        }
    }
}

# all tests try to answer questions. If somebody sets
# PERL_MM_USE_DEFAULT to true just to prevent blocking when I ask
# questions, they break these tests.
$ENV{PERL_MM_USE_DEFAULT} = 0;

use File::Copy qw(cp);
use File::Path qw(rmtree mkpath);

use lib "t";
use local_utils;

local_utils::cleanup_dot_cpan();
local_utils::prepare_dot_cpan();

BEGIN {
    for my $x ("_f",
               "_d",
               "read_myconfig",
               "mydiag",
               "mreq",
               "splitchunk",
               "test_name",
               "run_shell_cmd_lit",
              ) {
        no strict "refs";
        *$x = \&{"local_utils\::$x"};
    }
}

{
    local *FH;
    open *FH, (">"._f"t/dot-cpan/build/Something-From-Builddir-0.00.yml") or die;
    my @stat = stat $^X;
    my $dll = eval {OS2::DLLname()};
    my $mtime_dll = 0;
    if (defined $dll) {
        $mtime_dll = (-f $dll ? (stat(_))[9] : '-1');
    }
    print FH <<EOF;
---
distribution: !!perl/hash:CPAN::Distribution
  ID: A/AN/ANDK/Something-From-Builddir-0.00.tar.gz
  RO:
    CPAN_COMMENT: ~
    CPAN_USERID: ANDK
  archived: tar
  make: !!perl/hash:CPAN::Distrostatus
    COMMANDID: 78
    FAILED: ''
    TEXT: YES
  make_test: !!perl/hash:CPAN::Distrostatus
    COMMANDID: 78
    FAILED: ''
    TEXT: YES
  unwrapped: !!perl/hash:CPAN::Distrostatus
    COMMANDID: 78
    FAILED: ''
    TEXT: YES
  writemakefile: !!perl/hash:CPAN::Distrostatus
    COMMANDID: 78
    FAILED: ''
    TEXT: YES
perl:
  \$^X: "$^X"
  mtime_dll: "$mtime_dll"
  sitearchexp: "$Config::Config{sitearchexp}"
  mtime_\$^X: $stat[9]
time: 1
EOF
}
    close FH; #attempt to fix RT#43779
cp _f"t/CPAN/authors/id/A/AN/ANDK/CHECKSUMS.2nd",
    _f"t/dot-cpan/sources/authors/id/A/AN/ANDK/CHECKSUMS"
    or die "Could not cp t/CPAN/authors/id/A/AN/ANDK/CHECKSUMS.2nd ".
    "over t/dot-cpan/sources/authors/id/A/AN/ANDK/CHECKSUMS: $!";
cp _f"t/CPAN/CpanTestDummies-1.55.pm",
    _f"t/dot-cpan/Bundle/CpanTestDummies.pm" or die
    "Could not cp t/CPAN/CpanTestDummies-1.55.pm over ".
    "t/dot-cpan/Bundle/CpanTestDummies.pm: $!";
cp _f"distroprefs/ANDK.CPAN-Test-Dummy-Perl5-Make-Expect.yml",
    _f"t/dot-cpan/prefs/ANDK.CPAN-Test-Dummy-Perl5-Make-Expect.yml" or die
    "Could not cp distroprefs/ANDK.CPAN-Test-Dummy-Perl5-Make-Expect.yml to ".
    "t/dot-cpan/prefs/ANDK.CPAN-Test-Dummy-Perl5-Make-Expect.yml: $!";

my $cwd = Cwd::cwd;

open FH, (">" . _f"t/dot-cpan/prefs/TestDistroPrefsFile.yml") or die "Could not open: $!";
print FH <<EOF;
---
comment: "Having more than one yaml variable per file is OK?"
match:
  distribution: "matches never^"
---
match:
  module: "CPAN::Test::Dummy::Perl5::Build::Fails"
patches:
  - "$cwd/t/CPAN/TestPatch.txt"
EOF
close FH; #attempt to fix RT#43779

my @prgs;
{
    local $/;
    my $data = <DATA>;
    close DATA;
    $data =~ s/^=head.*//ms;
    @prgs = split /########.*/, $data;
}
my @modules = qw(
                 Archive::Zip
                 Data::Dumper
                 Digest::SHA
                 Expect
                 Module::Build
                 Term::ANSIColor
                 Term::ReadKey
                 Term::ReadLine
                 Text::Glob
                 YAML
                );
my @programs = qw(
                  patch
                 );

use Test::More;
plan tests => (
               scalar @prgs
               + 2                     # 2 histsize tests
               + 1                     # 1 RUN_EXPECT feedback
               + 1                     # run_..._cmd feedback
               + 1                     # spawn/open
               + 1                     # 1 count keys for 'o conf init variable'
               + 2                     # t/dot-cpan/.../ANDK dir exists and is empty
               # + scalar @modules
              );

{
    my $m;
    for $m (@modules) {
        $HAVE->{$m}++ if mreq $m;
    }
}
{
    my $p;
    my(@path) = split /$Config::Config{path_sep}/, $ENV{PATH};
    require CPAN::FirstTime;
    for $p (@programs) {
        $HAVE->{$p}++ if CPAN::FirstTime::find_exe($p,\@path);
    }
}
$HAVE->{"Term::ReadLine::Perl||Term::ReadLine::Gnu"}
    =
    $HAVE->{"Term::ReadLine::Perl"}
    || $HAVE->{"Term::ReadLine::Gnu"};
# My impression is that wehn Devel::Cover is running we cannot test
# Expect. Across several perl versions the same test was hanging. Go
# figure.
if ($INC{"Devel/Cover.pm"}) {
    delete $HAVE->{Expect};
}
read_myconfig;
is($CPAN::Config->{histsize},100,"histsize is 100 before testing");

{
    require CPAN::HandleConfig;
    my @ociv_tests = map { /P:o conf init (\w+)/ && $1 } @prgs;
    my %ociv;
    @ociv{@ociv_tests} = ();
    my $keys = %CPAN::HandleConfig::keys; # to keep warnings silent
    # kwnt => "key words not tested"
    my @kwnt = sort grep { not exists $ociv{$_} }
        grep { ! m/
                   ^(?:
                   urllist
                   |.*_hash
                   |.*_list
                   |applypatch
                   |build_dir_reuse
                   |build_requires_install_policy
                   |colorize_output
                   |colorize_print
                   |colorize_warn
                   |commands_quote
                   |inhibit_startup_message
                   |password
                   |patch
                   |prefs_dir
                   |proxy_(?:user|pass)
                   |randomize_urllist
                   |use_sqlite
                   |username
                   |yaml_module
                  )$/x }
            keys %CPAN::HandleConfig::keys;
    my $test_tuning = 0; # from time to time we set it to 1 to find
                         # untested config variables
    if ($test_tuning) {
        ok(@kwnt==0,"key words not tested[@kwnt]");
        die if @kwnt;
    } else {
        ok(1,"Another dummy test");
    }
}

my $prompt = "cpan>";
my $prompt_re = "cpan[^>]*>"; # note: replicated in DATA!
my $default_timeout = $ENV{CPAN_EXPECT_TIMEOUT} || 240;

$|=1;
if ($ENV{CPAN_RUN_SHELL_TEST_WITHOUT_EXPECT}) {
    $RUN_EXPECT = 0;
} elsif ($Config::Config{archname} =~ /solaris/) {
    # expect on some solaris is broken enough to fail this test but
    # good enough to survive everyday work with the CPAN shell.
    $RUN_EXPECT = 0;
} else {
    $RUN_EXPECT = 1;
}
ok(1,"RUN_EXPECT[$RUN_EXPECT]\$^X[$^X]");
my $expo;
my @run_shell_cmd_lit = run_shell_cmd_lit($cwd);
ok(scalar @run_shell_cmd_lit,"@run_shell_cmd_lit");
if ($RUN_EXPECT) {
    $expo = Expect->new;
    $ENV{LANG} = "C";
    my $spawned = $expo->spawn(@run_shell_cmd_lit);
    ok($spawned, "could at least spawn a process and \$! is[$!]");
    $expo->log_stdout(0);
    $expo->notransfer(1);
} else {
    delete $HAVE->{Expect};
    my $system = join(" ", map { "\"$_\"" } @run_shell_cmd_lit)." > test.out";
    # warn "# DEBUG: system[$system]";
    my $opened = open SYSTEM, "| $system";
    ok($opened, "Could at least open a process pipe and $! is [$!]");
}

my $skip_the_rest;
my @PAIRS;
TUPL: for my $i (0..$#prgs){
    my $chunk = $prgs[$i];
    my %h = splitchunk $chunk;
    my($status,$prog,$expected,$notexpected,
       $req,$test_timeout,$comment) = @h{qw(S P E e R T C N)};
    if ($skip_the_rest) {
        ok(1,"skipping");
        next TUPL;
    }
    if ($status) {
        chomp $status;
        if ($status eq "skip") {
            ok(1,"skipping");
            next TUPL;
        } elsif ($status eq "run") {
        } elsif ($status eq "quit") {
            ok(1,"skipping");
            $skip_the_rest++;
            next TUPL;
        } else {
            die "Alert: illegal status [$status]";
        }
    }

    unless (defined $expected or defined $notexpected or defined $prog) {
        ok(1,"empty test %h=(".join(" ",%h).")");
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
    for ($prog,$expected,$notexpected) {
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
            print SYSTEM "$sendprog\n";
        }
    } else {
        if ($RUN_EXPECT) {
            mydiag "PRESSING RETURN";
            $expo->send("\n");
        } else {
            print SYSTEM "\n";
        }
    }
    $expected .= "(?s:.*?$prompt_re)" unless $expected =~ /\(/;
    if ($RUN_EXPECT) {
        mydiag "EXPECT: $expected";
        if ($notexpected) {
            mydiag "NOTEXPECT: $notexpected";
        }
        my $this_timeout = $test_timeout || $default_timeout;
        if ($INC{"Devel/Cover.pm"}) {
            $this_timeout*=12;
        }
        $expo->expect(
                      $this_timeout,
                      [ eof => sub {
                            my $got = $expo->clear_accum;
                            mydiag "EOF on i[$i]prog[$prog]
expected[$expected]\ngot[$got]\n\n";
                            exit;
                        } ],
                      [ timeout => sub {
                            my $got = $expo->clear_accum;
                            # diag for cpantesters
                            diag "timed out on i[$i]prog[$prog]
expected[$expected]\ngot[$got]\n\n";
                            diag sprintf(
                                         "and perl says that [[[%s]]] %s match [[[%s]]]!",
                                         $got,
                                         $got=~/$expected/ ? "DOES" : "doesN'T",
                                         $expected
                                        );
                            exit;
                        } ],
                      '-re', $expected
                     );
        my $got = $expo->clear_accum;
        mydiag "GOT: $got\n";
        my $ok = 1;
        if ($notexpected) {
            if ($got =~ /$notexpected/) {
                mydiag sprintf "found offending [[[%s]]] in [[[%s]]]", $notexpected, $got;
                $ok = 0;
            }
        }
        $prog =~ s/^(\d)/$1/;
        $comment ||= "";
        ok($ok, test_name($prog,$comment));
    } else {
        $expected = "" if $prog =~ /\t/;
        push @PAIRS, [$prog,$expected,$notexpected,$comment];
    }
}
if ($RUN_EXPECT) {
    $expo->soft_close;
} else {
    close SYSTEM or die "Could not close SYSTEM filehandle: $!";
    mydiag "Finished running test script, going to read its output.";
    open SYSTEM, "test.out" or die "Could not open test.out for reading: $!";
    local $/;
    my $biggot = <SYSTEM>;
    close SYSTEM;
    my $pair;
    my $pos = 0;
    for $pair (@PAIRS) {
        my($prog,$expected,$notexpected,$comment) = @$pair;
        mydiag "NEXT: $prog";
        mydiag "EXPECT: $expected";
        if ($notexpected) {
            mydiag "NOTEXPECT: $notexpected";
        }
        my $ok = 1;
        if ($biggot =~ /(\G(?s:.*?)$expected)/gc) {
            my $got = $1;
            mydiag "GOT: $got\n";
            $pos = pos $biggot;
            if ($notexpected) {
                if ($got =~ /$notexpected/) {
                    mydiag sprintf "found offending [[[%s]]] in [[[%s]]]", $notexpected, $got;
                    $ok = 0;
                }
            }
        } else {
            my $pos = pos $biggot;
            my $got = substr($biggot,$pos,1024);
            # diag for cpantesters
            diag "FAILED at pos[$pos]\nprog[$prog]\nexpected[$expected]\ngot[$got]";
            last;
            $ok = 0;
        }
        ok($ok, test_name($prog,$comment));
    }
}

read_myconfig;
is($CPAN::Config->{histsize},100,"histsize is 100 after testing");
{
    my $dh;
    my $dir = _d"t/dot-cpan/sources/authors/id/A/AN/ANDK";
    my $ret = opendir $dh, $dir;
    ok($ret, "directory $dir exists");
    my @dirent = grep { -f _f"$dir/$_" } readdir $dh;
    ok(@dirent<=1, "directory $dir contains max 1 file. dirent[@dirent]");
}
local_utils::cleanup_dot_cpan();

# note: E=expect; P=program(=print); T=timeout; R=requires(=relies_on); N=Notes(internal); C=Comment(visible during testing)
__END__
########
#E:(?s:Enter 'h' for help.*?cpan[^>]*>)
########
#C:the answer depends on Net::Ping availability
#P:o conf init urllist
#E:(?s:Would you like me to automatically choose.+?yes\]|Autoselection disabled)
########
#P:n
#E:Would you like to.+?pick.+?mirror.+?list.+?yes(\])
########
#P:y
#E:Shall I use the cached mirror list.+?yes(\])
########
#P:y
#E:continent.+?(\])
########
#P:
#E:previous.+?(\])
########
#P:
#E:another URL.+?(\])
########
#P:
#E:(?s:New urllist.+?commit.+?(!).+?\])
########
#C:the answer depends on Net::Ping availability
#P:o conf init urllist
#E:(?s:Would you like me to automatically choose.+?yes\]|Autoselection disabled)
########
#P:n
#E:Would you like to.+?pick.+?mirror.+?list.+?yes(\])
########
#P:y
#E:Shall I use the cached mirror list.+?yes(\])
########
#P:y
#E:continent.+?(\])
########
#P:1-8
#E:(\])
########
#P:1-8
#E:(\])
########
#P:1-8
#E:(\])
########
#P:
#E:(?s:New urllist.+?commit.+?(!).+?\])
########
#P:o conf urllist
#E:linuxforum
########
#P:o conf urllist pop
########
#P:o conf urllist pop
########
#P:o conf urllist pop
########
#P:o conf urllist
#E:programming(?s:.+?)hknet
########
#P:o conf urllist push PUSH
########
#P:o conf urllist unshift UNSHIFT
########
#P:o conf urllist
#E:UNSHIFT(?s:.+?)programming(?s:.+?)hknet(?s:.+?)PUSH
########
#P:o conf urllist ONE TWO
########
#P:o conf urllist push PUSH
########
#P:o conf urllist unshift UNSHIFT
########
#P:o conf urllist
#E:UNSHIFT.+?\n.+?ONE.+\n.+?TWO.+\n.+?PUSH
########
#P:o conf defaults
########
#P:o conf urllist
########
#P:o conf build_cache
#E:build_cache
#S:run
########
#P:o conf init
#E:(?s:.*?configure.as.much.as.possible.automatically.*?\])
########
#P:yesplease
#E:(commit: wrote.+?MyConfig|You.do.not.have.write.permission)
########
#P:# manual
########
#P:# o debug all
########
#P:o conf histsize 101
#E:.  histsize.+?101
########
#P:o conf tar_verbosity v
#E:.  tar_verbosity.+?v
########
#P:o conf perl5lib_verbosity v
#E:.  perl5lib_verbosity.+?v
########
#P:o conf commit
#E:commit: wrote.+?MyConfig
########
#P:o conf histsize 102
#E:.  histsize.+?102
########
#P:o conf defaults
#E:reread
########
#P:o conf urllist
########
#P:o conf histsize
#E:histsize.+?101
########
#P:o conf histsize 100
#E:histsize.+?100
########
#P:o conf commit
#E:commit: wrote.+?MyConfig
########
#P:o conf urllist
#E:file:///.*?CPAN
########
#P:o conf init keep_source_where
#E:kept[\s\S]+?(\])
########
#P:/tmp
#E:
########
#P:o conf init build_cache
#E:(size.*?\])
########
#P:100
#E:
########
#P:o conf init build_dir
#E:Directory.+?(\])
########
#P:foo
#E:
########
#P:o conf init cache_metadata
#E:Cache.+?(\])
########
#P:y
#E:
########
#P:o conf init check_sigs
#E:Module::Signature is installed.+?(\])
########
#P:y
#E:
########
#P:o conf init cpan_home
#E:directory.+?(\])
########
#P:/tmp/must_be_a_createable_absolute_path/../
#E:
########
#P:o conf init make_arg
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init make_install_arg
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init make_install_make_command
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init makepl_arg
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init mbuild_arg
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init mbuild_install_arg
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init mbuild_install_build_command
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init mbuildpl_arg
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init pager
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init prefer_installer
#E:which\s+installer[\S\s]+?(\])
########
#P:EUMM
#E:
########
#P:o conf init prerequisites_policy
#E:follow[\S\s]+?ask[\S\s]+?ignore[\S\s]+?............(\])
########
#P:ask
#E:
########
#P:o conf init scan_cache
#E:............(\])
########
#P:atstart
#E:
########
#P:o conf init shell
#E:shell.*?(\?)
########
#P:foo
#E:
########
#P:o conf init show_upload_date
#E:upload[\S\s]+?date[\S\s]+?............(\])
########
#P:y
#E:
########
#P:o conf init term_is_latin
#E:............(\])
########
#P:n
#E:
########
#P:o conf init test_report
#E:............(\])
########
#P:n
#E:
########
#P:o conf init commandnumber_in_prompt
#E:command[\S\s]+?number[\S\s]+?............(\])
########
#P:y
#E:
########
#P:o conf init ftp_passive
#E:............(\])
########
#P:y
#E:
########
#P:o conf init ftp_proxy
#E:............(\])
########
#P:y
#E:(\?)
########
#P:u
#E:(\?)
########
#P:p
#E:
########
#P:o conf init http_proxy
#E:............(\])
########
#P:y
#E:(\?)
########
#P:u
#E:(\?)
########
#P:p
#E:
########
#P:o conf init no_proxy
#E:............(\])
########
#P:y
#E:(\?)
########
#P:u
#E:(\?)
########
#P:p
#E:
########
#P:o conf init getcwd
#E:............(\])
########
#P:cwd
#E:
########
#P:o conf init /histfile|histsize/
#E:(hist)
########
#P:/tmp/foo
#E:(save)
########
#P:100
#E:
########
#P:o conf init inactivity_timeout
#E:............(\])
########
#P:10000
#E:
########
#P:o conf init index_expire
#E:............(\])
########
#P:y
#E:
########
#P:o conf init term_ornaments
#E:............(\])
########
#P:y
#E:
########
#P:o conf defaults
########
#P:o conf urllist
########
#P:!print$ENV{HARNESS_PERL_SWITCHES}||"",$/
#E:
########
#P:!print $INC{"CPAN/Config.pm"} || "NoCpAnCoNfIg",$/
#E:NoCpAnCoNfIg
########
#P:!print $INC{"CPAN/MyConfig.pm"},$/
#E:CPAN/MyConfig.pm
########
#P:!print "\@INC: ", map { "    $_\n" } @INC
#E:
########
#P:!print "%INC: ", map { "    $_\n" } sort values %INC
#E:
########
#P:rtlprnft
#E:Unknown
########
#P:o conf ftp ""
########
#P:o conf build_dir_reuse 1
#E:
#R:YAML
########
#P:m Fcntl
#E:(?:Restored the state of (?:\d|none)|nothing to restore)[\s\S]+?Defines fcntl
#R:YAML
########
#P:a JHI
#E:Hietaniemi
########
#P:a ANDK JHI
#E:(?s:Andreas.*?Hietaniemi.*?items found)
########
#P:autobundle
#E:Wrote bundle file
########
#P:b
#E:(?s:Bundle::CpanTestDummies.*?items found)
########
#P:b
#E:(?s:Bundle::Snapshot\S+\s+\(N/A\))
########
#P:o debug all
#E:CPAN[\s\S]+?CacheMgr[\s\S]+?FirstTime
########
#P:b Bundle::CpanTestDummies
#E:\sCONTAINS.+?CPAN::Test::Dummy::Perl5::Make.+?CPAN::Test::Dummy::Perl5::Make::Zip
#R:Archive::Zip
########
#P:o debug 0
#E:turned off
########
#P:install ANDK/NotInChecksums-0.000.tar.gz
#E:(?s:awry.*?yes)
#R:Digest::SHA
########
#P:n
#R:Digest::SHA
########
#P:d ANDK/CPAN-Test-Dummy-Perl5-Make-1.05.tar.gz
#E:CONTAINSMODS\s+CPAN::Test::Dummy::Perl5::Make
########
#P:d ANDK/CPAN-Test-Dummy-Perl5-Make-1.05.tar.gz
#E:CPAN_USERID.*?ANDK.*?Andreas
########
#P:ls ANDK
#E:\d+\s+\d\d\d\d-\d\d-\d\d\sANDK/CPAN-Test-Dummy[\d\D]*?\d+\s+\d\d\d\d-\d\d-\d\d\sANDK/Devel-Symdump
########
#P:ls ANDK/CPAN*
#E:Text::Glob\s+loaded\s+ok[\d\D]*?CPAN-Test-Dummy
#R:Text::Glob
########
#P:force ls ANDK/CPAN*
#E:CPAN-Test-Dummy
#R:Text::Glob
########
#P:o debug all
#E:CPAN[\s\S]+?CacheMgr[\s\S]+?FirstTime
########
#P:test CPAN::Test::Dummy::Perl5::Make
#E:test\s+--\s+OK
########
#P:test CPAN::Test::Dummy::Perl5::Build
#E:\s\sANDK/CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz[\s\S]*?test\s+--\s+OK
#R:Module::Build
########
#P:o debug 0
#E:turned off
########
#P:test CPAN::Test::Dummy::Perl5::Make::Zip
#E:Has already been tested successfully
#R:Archive::Zip Module::Build
########
#P:failed
#E:Nothing
########
#P:o conf prefs_dir ""
#N:to hide the YAML file
########
#P:o conf prefs_dir
#E:prefs_dir
########
#P:test CPAN::Test::Dummy::Perl5::Build::Fails
#E:test\s+--\s+NOT OK
#R:Module::Build
#C:If this test fails, it's probably due to Test::Harness being < 2.62
########
#P:dump CPAN::Test::Dummy::Perl5::Make
#E:\}.+?CPAN::Module.+?;
#R:Data::Dumper
########
#P:install CPAN::Test::Dummy::Perl5::Make::Failearly
#E:Failed during this command[\d\D]+?writemakefile NO
########
#P:test CPAN::Test::Dummy::Perl5::NotExists
#E:Warning:
########
#P:clean NOTEXISTS/Notxists-0.000.tar.gz
#E:nothing done
########
#P:failed
#E:Test-Dummy-Perl5-Build-Fails.*?make_test NO
#R:Module::Build
########
#P:failed
#E:Test-Dummy-Perl5-Make-Failearly.*?writemakefile NO
########
#P:o conf commandnumber_in_prompt 1
########
#P:o conf build_cache 0.1
#E:build_cache
########
#P:reload index
#E:staleness
########
#P:m /l/
#E:(?s:Perl5.*?Fcntl.*?items)
########
#P:i /l/
#E:(?s:Dummies.*?Dummy.*?Perl5.*?Fcntl.*?items)
########
#P:h
#E:(?s:make.*?test.*?install.*?force.*?notest.*?reload)
########
#P:o conf
#E:commit[\d\D]*?build_cache[\d\D]*?cpan_home[\d\D]*?inhibit_startup_message[\d\D]*?urllist[\d\D]*?wget
########
#P:o conf prefer_installer EUMM
#E:EUMM\]
########
#P:dump CPAN::Test::Dummy::Perl5::BuildOrMake
#E:\}.+?CPAN::Module
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz
#E:\}.+?CPAN::Distribution
########
#P:make CPAN::Test::Dummy::Perl5::BuildOrMake
#E:(?s:Running make.*?Writing Makefile.*?make["']?\s+-- OK)
#C:first try
########
#P:o conf prefer_installer MB
#R:Module::Build
########
#P:force get CPAN::Test::Dummy::Perl5::BuildOrMake
#E:CPAN-Test-Dummy-Perl5-BuildOrMake-1.02/Build.PL
#R:Module::Build
########
#P:dump CPAN::Test::Dummy::Perl5::BuildOrMake
#E:\}.+?CPAN::Module
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz
#E:\}.+?CPAN::Distributio.
########
#P:make CPAN::Test::Dummy::Perl5::BuildOrMake
#E:(?s:Build\s+-- OK)
#R:Module::Build
#C:second try
########
#P:force get ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz
#E:CPAN-Test-Dummy-Perl5-BuildOrMake-1.02/Build.PL
#R:Module::Build
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz
#E:\}.+?CPAN::Distributio.
########
#P:notest test ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz
#E:Build\s+-- OK[\s\S]+?Skipping test
#R:Module::Build
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz
#e:'notest' => 1,
########
#P:dump Bundle::CpanTestDummies
#E:\},.*?CPAN::Bundle.*?;
#R:Module::Build
########
#P:dump CPAN::Test::Dummy::Perl5::Build::Fails
#E:\},.*?CPAN::Module.*?;
#R:Module::Build
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz
#E:\},.*?CPAN::Distribution.*?;
#R:Module::Build
########
#P:test Bundle::CpanTestDummies
#E:Test-Dummy-Perl5-Build-Fails-.+?make_test\s+NO
#R:Module::Build
########
#P:get Bundle::CpanTestDummies
#E:Has already been unwrapped
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz
#E:\}.*?CPAN::Distribution
########
#P:d ANDK/CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz
#R:Module::Build
#E:prereq_pm\s+build_requires:\S+requires:\S+
########
#P:notest make Bundle::CpanTestDummies
#E:Has already been made
########
#P:clean Bundle::CpanTestDummies
#E:Running clean[\S\s]+?Running clean[\S\s]+?Running clean
########
#P:clean Bundle::CpanTestDummies
#E:make clean already called once
########
#P:r
#E:(All modules are up to date|installed modules|Fcntl)
########
#P:r /cnt/
#E:(All modules are up to date|installed modules|Fcntl)
########
#P:upgrade /cnt/
#E:(All modules are up to date|installed modules|Fcntl)
########
#P:! $CPAN::Config->{make_install_make_command} = "'$^X' -le 'print q{SAW MAKE}'"
########
#P:! $CPAN::Config->{mbuild_install_build_command} = "'$^X' -le 'print q{SAW MBUILD}'"
########
#P:o conf build_requires_install_policy no
#E:build_requires_install_policy
########
#P:install CPAN::Test::Dummy::Perl5::Build::DepeFails
#E:is up to date|Failed during[\S\s]+?Build-DepeFails.+?dependenc\S+ not OK.+?Build::Fails
#N: "is up to date" is for when they have it installed in INC
#R:Module::Build
########
#P:install CPAN::Test::Dummy::Perl5::Make::CircDepeOne
#E:is up to date|Recursive dependency
########
#P:o conf defaults
########
#P:force get CPAN::Test::Dummy::Perl5::Build::Fails
#E:D i s t r o[\s\S]+?TestDistroPrefsFile.yml\[1[\s\S]+?patch
#R:YAML patch
########
#P:test ANDK/CPAN-Test-Dummy-Perl5-Make-Expect-1.00.tar.gz
#E:D i s t r o[\s\S]+?COMMANDLINE[\s\S]+?test -- OK
#R:Expect YAML
########
#P:test CPAN::Test::Dummy::Perl5::Build::Fails
#E:test -- OK
#R:YAML patch Module::Build
########
#P:u /--/
#E:No modules found for
########
#P:m _NEXISTE_::_NEXISTE_
#E:Defines nothing
########
#P:m /_NEXISTE_/
#E:Contact Author J. Cpantest Hietaniemi
########
#P:notest
#E:Pragma.*?method
########
#P:o conf help
#E:(?s:commit.*?defaults.*?help.*?init.*?urllist)
########
#P:o conf inhibit_\t
#E:inhibit_startup_message
#R:Term::ReadLine::Perl||Term::ReadLine::Gnu
########
#P:help
#E:Display Information
########
#P:h
#E:Display Information
########
#P:?
#E:Display Information
########
#P:help foo
#E:foo: No help available
########
#P:h foo
#E:foo: No help available
########
#P:? foo
#E:foo: No help available
########
#P:quit
#E:(removed\.)
########


=head1 NAME

30shell - The (old) main test script for CPAN.pm (superceded mostly by 31sections.t)

=head1 SYNOPSIS

  make test                        # standard

  make test TEST_FILES=t/30shell.t # traditional on file invocation

  make testshell-with-protocol     # collects output in ../protocols

=head1 DESCRIPTION


=head2 Coverage

C<30shell.coverage> collects results from Devel::Cover

=head2 How this script works

The heart of the testing mechanism is t/30shell.t which is based on
Expect and as such is able to test a shell session. The following
provides an overview about how this testscript works.

After the __END__ token you find small groups of lines like the
following:

    ########
    #P:make CPAN::Test::Dummy::Perl5::BuildOrMake
    #E:(?s:Running Build.*?Creating new.*?Build\s+-- OK)
    #R:Module::Build
    #T:15
    #C:comment
    #N:internal note
    ########

P stands for program or print

E for expect

T for timeout

R for requires or relies on

C for comment (should be visible during testing)

S for status

N for notes (just for the test writer, otherwise invisible)


The script starts a CPAN shell and feeds it with chunks. The P line is
injected and the output of the shell is parsed and compared to the
expression in the E line. With T the timeout can be changed (the
default is rather low, maybe 30 seconds, see the code for details).
The expression in R is used to filter tests. The keyword in S may be
one of C<run> to run this test, C<skip> to skip it, and C<quit> to
stop testing immediately when this test is reached.

To get reliable and debuggable results, Expect.pm should be installed.
Without Expect.pm, a fallback mode is started that should in principle
also succeed but is pretty hard to debug because there is no mechanism
to sync state between reader and writer.

=head2 How to add new pseudo distributions

To make reproducable tests we need a shell session that is based on a
clone of a miniaturized CPAN site. This site lives under
t/CPAN/{authors,modules}.

The first distribution in the fake CPAN site was
CPAN-Test-Dummy-Perl5-Make-1.01.tar.gz in the
./CPAN/authors/id/A/AN/ANDK/ directory which was a clone of
PITA::Test::Dummy::Perl5::Make.

We need distros based on the following (and more) criteria:

 Testing:        success, failure
 Installer:      EU:MM, M:B, M:I
 YAML:           with YAML, with YAML::Syck, without
 SIGNATURE:      with, without
 Zipping:        tar.gz, tar.bz2, zip
 Requires:       requires, build_requires

Any new distro must be separately available on CPAN so that our
CHECKSUMS files can be the real (signed) ones and we need not
introduce a backdoor into the shell to ignore signatures.

To add a new distro, the following steps must be taken:

(1) Collect the source

- mkdir the author's directory if it doesn't exist yet; e.g.

  mkdir -p t/CPAN/authors/id/A/AN/ANDK
  cd t/CPAN/authors/id/A/AN/ANDK

- introduce the whole source code under the author's
  homedir, often just a copy; e.g.

  rsync -va CPAN-Test-Dummy-Perl5-Make-CircDepeOne CPAN-Test-Dummy-Perl5-Make-Expect

- add the source code directory with a trailing slash to ../MANIFEST.SKIP

- finish now the distro until it does what you intended

(2) Create the distro tarball

- add a stanza to CPAN.pm's ../Makefile.PL that produces the distro with
  the whole dependency on all files within the distro and moves it up
  into the author's homedir. Run this with 'make testdistros'.

- *git add* the new testdistro (first we did that, then we stopped
  doing it for "it makes no sense"; then I realized we need to do it
  because with a newer MakeMaker or Module::Build we cannot regenerate
  them byte-by-byte and lose the signature war)

- add it to the ../MANIFEST

(3) Upload and embed into our "./CPAN" minicpan

- verify that 'make dist' on CPAN.pm still works

- if you want more distros, repeat (1) and (2) now

- upload the distro(s) to the CPAN and wait until the indexer has
  produced a CHECKSUMS file

- git add/commit the relevant CHECKSUMS files

- add the CHECKSUMS files to the MANIFEST

(4) Work with the results

- verify that 'make dist' on CPAN.pm still works

- add the distro(s) to CPAN/modules/02packages.details.txt: this step
  needs special care: pay attention to both the module version and the
  distro name; if there is more than one module or bundle inside the
  distro, write two lines; watch the line count;

- if this distro replaces another, git-rm the other one

- if this distro replaces another, fix the tests that rely on the
  other one

- add the test to 30shell.t that triggered the demand for a new distro

=head2 Problems

With SVN we had the problem that when you set up a new working copy of
the SVN repository, you first had to run 'make testdistros' to get the
pseudo distros that were not in the repository. This made too many
testdistros, so you had to run 'svk st' and see which were marked with
'M'. Then you had to revert those and then the 30shell test should
succeed. This has now been corrected for git repos.

=cut


# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
