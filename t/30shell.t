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
        unless ($ENV{CPAN_RUN_SHELL_TEST_WITHOUT_EXPECT}) {
            print "1..0 # Skip: no Expect, maybe try env CPAN_RUN_SHELL_TEST_WITHOUT_EXPECT=1\n";
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
cp _f"t/CPAN/TestMirroredBy", _f"t/dot-cpan/sources/MIRRORED.BY"
    or die "Could not cp t/CPAN/TestMirroredBy over t/dor-cpan/sources/MIRRORED.BY: $!";
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
    my $data = <DATA>;
    close DATA;
    $data =~ s/^=head.*//s;
    @prgs = split /########.*/, $data;
}
my @modules = qw(
                 Digest::SHA
                 Term::ReadKey
                 Term::ReadLine
                 Text::Glob
                 Module::Build
                 Archive::Zip
                 Data::Dumper
                 Term::ANSIColor
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
    my $keys = %CPAN::HandleConfig::keys; # to keep warnings silent
    my @kwnt = sort grep { not exists $ociv{$_} }
        grep { ! m/
                   ^(?:
                   urllist
                   |inhibit_startup_message
                   |username
                   |password
                   |proxy_(?:user|pass)
                   |.*_list
                   |.*_hash
                  )$/x }
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
my $timeout = 20;

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
if ($HAVE_EXPECT) {
    if ($ENV{CPAN_RUN_SHELL_TEST_WITHOUT_EXPECT}) {
        $RUN_EXPECT = 0;
    } else {
        $RUN_EXPECT = 1;
    }
} else {
    if ($ENV{CPAN_RUN_SHELL_TEST}) {
        $RUN_EXPECT = 1;
    } else {
        $RUN_EXPECT = 0;
    }
}
ok(1,"RUN_EXPECT[$RUN_EXPECT]");
if ($RUN_EXPECT) {
    $expo = Expect->new;
    $ENV{LANG} = "C";
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
    my @s = split /(^\#[A-Z]:)/m, $ch;
    shift @s; # leading empty string
    for (my $i = 0; $i < @s; $i+=2) {
        $s[$i] =~ s/\#//;
        $s[$i] =~ s/://;
    }
    @s;
}

my $skip_the_rest;
TUPL: for my $i (0..$#prgs){
    my $chunk = $prgs[$i];
    my %h = splitchunk $chunk;
    my($status,$prog,$expected,$req,$test_timeout,$comment) = @h{qw(S P E R T C)};
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
    } else {
        if ($RUN_EXPECT) {
            mydiag "PRESSING RETURN";
            $expo->send("\n");
        } else {
            print SYSTEM "# PRESSING RETURN\n";
            print SYSTEM "\n";
        }
    }
    $expected .= "(?s:.*?$prompt_re)" unless $expected =~ /\(/;
    if ($RUN_EXPECT) {
        mydiag "EXPECT: $expected";
        $expo->expect(
                      $test_timeout || $timeout,
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
        $prog =~ s/^(\d)/$1/;
        $comment ||= "";
        ok(1, "$comment" . ($prog ? " (testing command '$prog')" : "[empty RET]"));
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
is($CPAN::Config->{histsize},100);
rmtree _d"t/dot-cpan";

# note: E=expect; P=program(=print); T=timeout; R=requires(=relies_on)
__END__
########
#E:(?s:ReadLine support (enabled|suppressed|available).*?cpan[^>]*?>)
########
#P:o conf init urllist
#E:(MIRR).+?y\]
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
#E:(?s:New set.+?commit.+?(!).+?\])
########
#P:o conf init urllist
#E:MIRR.+?(\])
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
#E:(?s:New set.+?commit.+?(!).+?\])
########
#P:o conf urllist
########
#P:o conf defaults
########
#P:o conf build_cache
#E:build_cache
#S:run
########
#P:o conf init
#E:(?s:.*?configure.as.much.as.possible.automatically.*?\])
########
#P:yesplease
#E:commit: wrote.+?MyConfig
#T:60
########
#P:# o debug all
########
#P:o conf histsize 101
#E:.  histsize.+?101
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
#E:kept.+?(\])
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
#P:o conf init bzip2
#E:Where.+?bzip2.+?(\])
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
#P:o conf init curl
#E:Where.+?(\])
########
#P:foo
#E:
########
#P:o conf init gpg
#E:Where.+?(\])
########
#P:foo
#E:
########
#P:o conf init gzip
#E:Where.+?(\])
########
#P:foo
#E:
########
#P:o conf init lynx
#E:Where.+?(\])
########
#P:foo
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
#P:o conf init ncftp
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init ncftpget
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
#E:............(\])
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
#E:............(\])
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
#P:o conf init tar
#E:............(\])
########
#P:foo
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
#P:o conf init unzip
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init wget
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init commandnumber_in_prompt
#E:command[\S\s]+?number[\S\s]+?............(\])
########
#P:y
#E:
########
#P:o conf init ftp
#E:............(\])
########
#P:foo
#E:
########
#P:o conf init make
#E:............(\])
########
#P:foo
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
#P:o conf init histfile
#E:(hist)
########
#P:/tmp/foo
#E:(save)
########
#P:100
#E:
########
#P:o conf init histsize
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
#P:m Fcntl
#E:Defines fcntl
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
#P:b Bundle::CpanTestDummies
#E:\sCONTAINS.+?CPAN::Test::Dummy::Perl5::Make.+?CPAN::Test::Dummy::Perl5::Make::Zip
#R:Archive::Zip
########
#P:install ANDK/NotInChecksums-0.000.tar.gz
#E:(?s:awry.*?yes)
#R:Digest::SHA
########
#P:n
#R:Digest::SHA
########
#P:d ANDK/CPAN-Test-Dummy-Perl5-Make-1.04.tar.gz
#E:CONTAINSMODS\s+CPAN::Test::Dummy::Perl5::Make
########
#P:d ANDK/CPAN-Test-Dummy-Perl5-Make-1.04.tar.gz
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
#P:test CPAN::Test::Dummy::Perl5::Make
#E:test\s+--\s+OK
########
#P:test CPAN::Test::Dummy::Perl5::Build
#E:test\s+--\s+OK
#R:Module::Build
########
#P:test CPAN::Test::Dummy::Perl5::Make::Zip
#E:test\s+--\s+OK
#R:Archive::Zip
########
#P:failed
#E:Nothing
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
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.01.tar.gz
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
#E:Removing previously used
#R:Module::Build
########
#P:dump CPAN::Test::Dummy::Perl5::BuildOrMake
#E:\}.+?CPAN::Module
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.01.tar.gz
#E:\}.+?CPAN::Distributio.
########
#P:make CPAN::Test::Dummy::Perl5::BuildOrMake
#E:(?s:Running Build.*?Creating new.*?Build\s+-- OK)
#R:Module::Build
#C:second try
########
#P:dump Bundle::CpanTestDummies
#E:\}
#R:Module::Build
########
#P:dump CPAN::Test::Dummy::Perl5::Build::Fails
#E:\}
#R:Module::Build
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.01.tar.gz
#E:\}
#R:Module::Build
########
#P:test Bundle::CpanTestDummies
#E:Test-Dummy-Perl5-Build-Fails-.+?make_test\s+NO
#R:Module::Build
#T:30
########
#P:get Bundle::CpanTestDummies
#E:Is already unwrapped
########
#P:dump ANDK/CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz
#E:\}.*?CPAN::Distribution
########
#P:notest make Bundle::CpanTestDummies
#E:Has already been processed
########
#P:clean Bundle::CpanTestDummies
#E:Failed during this command
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
#E:SAW MAKE
########
#P:! $CPAN::Config->{mbuild_install_build_command} = "'$^X' -le 'print q{SAW MBUILD}'"
#E:SAW MBUILD
########
#P:o conf build_requires_install_policy no
#E:build_requires_install_policy
########
#P:install CPAN::Test::Dummy::Perl5::Build
#E:is up to date|SAW MAKE[\s\S]+?SAW MAKE[\s\S]+?SAW MBUILD
#C: "is up to date" is for when they have it installed in INC
#R:Module::Build
########
#P:install CPAN::Test::Dummy::Perl5::Build::DepeFails
#E:is up to date|Failed during[\S\s]+?Build-DepeFails.+?dependenc\S+ not OK.+?Build::Fails
#C: "is up to date" is for when they have it installed in INC
#R:Module::Build
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
#P:quit
#E:(removed\.)
########


=head1 NAME

30shell - The main test script for CPAN.pm

=head1 SYNOPSIS

  make test                        # standard

  make test TEST_FILES=t/30shell.t # traditional on file invocation

  make testshell-with-protocol     # collects output in ../protocols

=head1 DESCRIPTION


=head2 Coverage

C<30shell.coverage> collects results from Devel::Cover

=head2 How this script works

In the following I want to provide an overview about how this
testscript works.

After the __END__ token you find small groups of lines like the
following:

    ########
    #P:make CPAN::Test::Dummy::Perl5::BuildOrMake
    #E:(?s:Running Build.*?Creating new.*?Build\s+-- OK)
    #R:Module::Build
    #T:15
    #C:comment
    ########

P stands for program or print

E for expect

T for timeout

R for requires or relies on

C for comment

S for status


The script starts a CPAN shell and feed it the chunks such that the P
line is injected, the output of the shell is parsed and compared to
the expression in the E line. With T the timeout can be changed (the
default is rather low, maybe 10 seconds, see the code for details).
The expression in R is used to filter tests. The keyword in S may be
one of C<run> to run this test, C<skip> to skip it, and C<quit> to
stop testing immediately when this test is reached.

To get reliable and debuggable results, Expect.pm should be installed.
Without Expect.pm, a fallback mode is started that should in principle
also succeed but is pretty hard to debug because there is no mechanism
to sync state between reader and writer.

=head2 How to add new pseudo distributions

The heart of the testing mechanism is shell.t which is based on Expect
and as such is able to test a shell session. To make reproducable
tests we need a shell session that is based on a clone of a
miniaturized CPAN site. This site lives under t/CPAN/{authors,modules}.

The first distribution in the fake CPAN site was
CPAN-Test-Dummy-Perl5-Make-1.01.tar.gz in the
./CPAN/authors/id/A/AN/ANDK/ directory which was a clone of
PITA::Test::Dummy::Perl5::Make.

This document describes which distros we need and how they can be
added.

We need distros based on the following (and more) criteria:

 Testing:        success/failure
 Installer:      EU:MM/M:B/M:I
 YAML:           with/without
 SIGNATURE:      with/without
 Zipping:        tar.gz/tar.bz2/zip
 Requires:       requires/build_requires

Any new distro must be separately available on CPAN so that our
CHECKSUMS files can be the real (signed) ones and we need not
introduce a backdoor into the shell to ignore signatures.

To add a new distro, the following steps must be taken:

(1) Collect the source

- svn mkdir the author's directory if it doesn't exist yet

- svn add (or svn cp) the whole source code under the author's homedir

- add the source code directory with a trailing slash to MANIFEST.SKIP

- finish now the distro until it does what you intended

(2) Create the distro zipfile

- add a stanza to CPAN.pm's Makefile.PL that produces the distro with
  the whole dependency on all files within the distro and moves it up
  into the author's homedir. Run this with 'make testdistros'.

- *svn add* the new testdistro (first we did that, then we stopped
  doing it for "it makes no sense"; then I realized we need to do it
  because with a newer MakeMaker or Moule::Build we cannot regenerate
  them byte-by-byte and lose the signature war)

- add it to the MANIFEST

(3) Upload and embed into our minicpan

- verify that 'make dist' on CPAN.pm still works

- if you want more distros, repeat (1) and (2) now

- upload the distro(s) to the CPAN and wait until the indexer has
  produced a CHECKSUMS file

- svn add/ci the relevant CHECKSUMS files

- add the CHECKSUMS files to the MANIFEST

(4) Work with the results

- verify that 'make dist' on CPAN.pm still works

- add the distro(s) to CPAN/modules/02packages.details.txt: this step
  needs special care: pay attention to both the module version and the
  distro name; if there is more than one module or bundle inside the
  distro, write two lines; watch the line count;

- if this distro replaces another, svn rm the other one

- if this distro replaces another, fix the tests that rely on the
  other one

- add the test to shell.t that triggered the demand for a new distro

=cut


# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
