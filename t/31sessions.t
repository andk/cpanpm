$|=1;
BEGIN {
    unshift @INC, './lib', './t';

    require local_utils;
    local_utils::cleanup_dot_cpan();
    local_utils::prepare_dot_cpan();
    local_utils::read_myconfig();
    require CPAN::MyConfig;
    require CPAN;

    CPAN::HandleConfig->load;
    $CPAN::Config->{load_module_verbosity} = q[none];
    my $yaml_module = CPAN::_yaml_module();
    my $exit_message;
    # local $CPAN::Be_Silent = 1; # not the official interface!!!
    if ($CPAN::META->has_inst($yaml_module)) {
        # print "# yaml_module[$yaml_module] loadable\n";
    } else {
        $exit_message = "Yaml module [$yaml_module] not installed";
    }
    if ($CPAN::META->has_inst("Module::Build")) {
        # print "# Module::Build loadable\n";
    } else {
        $exit_message = "Module::Build not installed";
    }
    if ($CPAN::META->has_inst("File::Temp")) {
        # print "# File::Temp loadable\n";
    } else {
        $exit_message = "File::Temp not available";
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
        if ($CPAN::META->has_inst($tabu)) {
            $exit_message = "Found module '$tabu' installed. Cannot run this test.";
            last TABU;
        }
    }
    unless ($exit_message) {
        if ($YAML::VERSION && $YAML::VERSION < 0.60) {
            $exit_message = "YAML v$YAML::VERSION too old for this test";
        }
    }
    unless ($exit_message) {
        my @pairs = (
                     [unzip => "Archive::Zip"],
                     [tar => "Archive::Tar"],
                     [gzip => "Compress::Zlib"],
                    );
        my $p;
        my(@path) = split /$Config::Config{path_sep}/, $ENV{PATH};
        require CPAN::FirstTime;
        for $pair (@pairs) {
            my($prg,$module) = @$pair;
            next if $CPAN::META->has_inst($module);
            next if CPAN::FirstTime::find_exe($prg,\@path);
            $exit_message = "Module '$module' not installed and fallback program '$prg' not found in path[@path].";
            last;
        }
    }
    if ($exit_message) {
        $|=1;
        print "1..0 # SKIP $exit_message\n";
        eval "require POSIX; 1" and POSIX::_exit(0);
        warn "Error while trying to load POSIX: $@";
        exit(0);
    }
}

use strict;
use File::Copy qw(cp);
use File::Spec;
use Test::More;

=pod

It was our intent to shape the force pragma as follows:

Do we want to repeat testing?

                    command     session     restored_state
        Distro
          OK          no          no          no
          FAIL        no          yes         yes
        Module/Bundle
          OK/FAIL     pass everything through to underlying distros

=cut

BEGIN {
    for my $x (
               "_f",
               "read_myconfig",
               "mydiag",
               "run_shell_cmd_lit",
              ) {
        no strict "refs";
        *$x = \&{"local_utils\::$x"};
    }
}
END {
    local_utils::cleanup_dot_cpan();
}
our(@SESSIONS, $default_system, $prompt_re);
BEGIN {
    my $cwd = Cwd::cwd;

    #  2>&1 is no solution. I intertwingled them, I missed a few "ok"
    $default_system = join(" ", map { "\"$_\"" } run_shell_cmd_lit($cwd))." > test.out";

    open FH, (">" . _f"t/dot-cpan/prefs/TestDistroPrefsFile.yml") or die "Could not open: $!";
    print FH <<EOF;
---
match:
  distribution: "ANDK/CPAN-Test-Dummy-Perl5-Make-Features-"
features:
  - "rice"
EOF
    close FH or die "Could not close 't/dot-cpan/prefs/TestDistroPrefsFile.yml': $!";

    @SESSIONS =
        (
         {
          name => "urllist empty",
          perl_mm_use_default => 0,
          requires => [qw(Expect)],
          pairs =>
          [
           "o conf connect_to_internet_ok 0" => ".",
           "o conf urllist pop" => ".",
           "o conf urllist" => "urllist\\s+Type.+all configuration items",
           "test CPAN::Test::Dummy::Perl5::Make" => "Client not fully configured",
           "o conf init urllist\nn\nn\nhttp://cpan.example.com/\n\n" => "enter your CPAN[\\s\\S]+Enter another URL[\\s\\S]+New urllist\\s+http://cpan.example.com/",
          ]
         },
         {
          name => "unambiguous regexps",
          pairs =>
          [
           "d    /CPAN-Test-Dummy-Perl5-Make-1/" => "Distribution id = A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-1",
           "test /CPAN-Test-Dummy-Perl5-Make-1/" => "test -- OK",
           "test /CPAN-Test-Dummy-Perl5/" => "Sorry, test with a regular",
          ]},
         {
          name => "reordering urllist",
          perl_mm_use_default => 0,
          gets_mirrored_by => 1,
          pairs =>
          [
           "o conf connect_to_internet_ok 0" => ".",
           "o conf urllist ONE TWO THREE FOUR" => ".",
           # we are asked if using the found urllist is ok, we say
           # yes, then we say 8 for the previous picks, then we pick
           # items 4 and 2 in that order
           "o conf init urllist\nn\ny\nt\n8\n4 2\n" => "New urllist\\s+FOUR\\s+TWO",
          ]
         },
         {
          name => "the historically first",
          perl_mm_use_default => 1,
          pairs =>
          [
           "dump \$::x=4*6+1" => "= 25;",
           "dump \$::x=40*6+1" => "= 241;",
           "dump \$::x=40*60+1" => "= 2401;",
           "o conf init" => "commit: wrote",
           "o conf patch ' '" => ".", # prevent that C:T:D:P:B:Fails succeeds by patching
           "test CPAN::Test::Dummy::Perl5::Make" => "t/00_load\.+ok",
           "get CPAN::Test::Dummy::Perl5::Make" => "Has already been unwrapped",
           "make CPAN::Test::Dummy::Perl5::Make" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made)",
           "test CPAN::Test::Dummy::Perl5::Make" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made.*
                                                  Has.already.been.tested.successfully)",
           "force test CPAN::Test::Dummy::Perl5::Make" => "t/00_load\.+ok",
           "test CPAN::Test::Dummy::Perl5::Build::Fails" => "(?i:t/00_load.+FAILED)",
           "test CPAN::Test::Dummy::Perl5::Build::Fails" => "(?i:t/00_load.+FAILED)",
           "get CPAN::Test::Dummy::Perl5::Build::Fails" => "Has already been unwrapped",
           "make CPAN::Test::Dummy::Perl5::Build::Fails" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made)",
           "force get CPAN::Test::Dummy::Perl5::Build::Fails" => "(?sx:security.checks.disabled
                         |Checksum.for.*CPAN-Test-Dummy-Perl5-Build-Fails-1.03.tar.gz.ok)",
           "o conf build_dir_reuse 1" => "build_dir_reuse",
           "o conf commit" => "commit: wrote",
          ]
         },
         {
          name => "the historically second",
          perl_mm_use_default => 1,
          pairs =>
          [
           "get CPAN::Test::Dummy::Perl5::Make" => "Has already been unwrapped",
           "make CPAN/Test/Dummy/Perl5/Make.pm" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made)",
           "test CPAN::Test::Dummy::Perl5::Make" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made.*
                                                  Has.already.been.tested.successfully)",
           "get CPAN::Test::Dummy::Perl5::Build::Fails" => "Has already been unwrapped",
           "make CPAN::Test::Dummy::Perl5::Build::Fails" => "Has.already.been.unwrapped",
           "test CPAN::Test::Dummy::Perl5::Build::Fails" => "(?i:t/00_load.+FAILED)",
           "o conf dontload_list push YAML" => ".",
           "o conf dontload_list push YAML::Syck" => ".",
           "o conf dontload_list push Parse::CPAN::Meta" => ".",
           "o conf dontload_list push CPAN::Meta" => ".",
           "o conf commit" => "commit: wrote",
          ]
         },
         {
          name => "after we turned off yaml with dontload",
          perl_mm_use_default => 1,
          pairs =>
          [
           # Note: I had C<cannot.parse.*> also here (for FTPstats) but
           # this does not come under some currently unknown circumstances

           "get CPAN::Test::Dummy::Perl5::Make" => "(?sx:
                     not.installed,.falling.back.*
                     will.not.store.persistent.state)",
           "make CPAN::Test::Dummy::Perl5::Make" => "Falling back to other methods to determine prerequisites",
           "test CPAN::Test::Dummy::Perl5::Make" => "All tests successful",
           "clean CPAN::Test::Dummy::Perl5::Make" => "clean.*-- OK",
          ]
         },
         {
          name => "focussing test circdepe",
          perl_mm_use_default => 1,
          pairs =>
          [
           "dump \$::x=4*6+1" => "= 25;",
           "test CPAN::Test::Dummy::Perl5::Make::CircDepeOne" =>
           "(?xs:
  Running.test.for.module.+CPAN::Test::Dummy::Perl5::Make::CircDepeOne.+
  CPAN::Test::Dummy::Perl5::Make::CircDepeThree.+\\[requires\\].+
  CPAN::Test::Dummy::Perl5::Make::CircDepeTwo.+\\[requires\\].+
  CPAN::Test::Dummy::Perl5::Make::CircDepeOne.+\\[requires\\].+
  Recursive.dependency.detected
)",
          ],
         },
         {
          name => "focussing test unsatprereq",
          perl_mm_use_default => 1,
          pairs =>
          [
           "dump \$::x=4*6+1" => "= 25;",
           "test CPAN::Test::Dummy::Perl5::Make::UnsatPrereq" =>
           "(?xs:
  Warning:.+?
  Prerequisite.+?
  CPAN::Test::Dummy::Perl5::Make.+?
  99999999.99.+?
  not[ ]available[ ]according[ ]to[ ]the[ ]ind
)",
          ],
         },
         {
          name => "halt_on_failure",
          perl_mm_use_default => 1,
          pairs =>
          [
           "dump \$::x=4*6+1" => "= 25;",
           "o conf halt_on_failure 1" => "1",
           "test CPAN::Test::Dummy::Perl5::Build::Fails CPAN::Test::Dummy::Perl5::Make::Failearly" =>
           "FAIL",
           # must not see Failearly in the failed summary
           "failed" => q{(?x:Failed \s during \s this \s session: \s+
                               \S+ Build-Fails \S+: \s+ make_test \s+ NO \s*\z)},
           "o conf dontload_list pop" => ".",
           "o conf dontload_list pop" => ".",
           "o conf dontload_list pop" => ".",
           "o conf dontload_list pop" => ".",
           "o conf commit" => "commit: wrote",
          ],
         },
         {
          # loads distroprefs for the C:T:D:P:M:Features module where
          # we demand the feature "rice". this feature then requires
          # CPAN::Test::Dummy::Perl5::Build which we do not have so we
          # build it first and then C:T:D:P:M:Features can also be
          # built
          name => "optional_features",
          perl_mm_use_default => 1,
          pairs =>
          [
           "dump \$::x=6*6+9" => "= 45;",
           "o conf build_dir" => "build_dir",
           "o conf prefs_dir '$cwd/t/dot-cpan/prefs'" => "(?m:prefs_dir.+prefs)",
           "test CPAN::Test::Dummy::Perl5::Make::Features" =>
           "(?sx:Builds.rice.+
          ANDK/CPAN-Test-Dummy-Perl5-Build-\\d.+
          \\./Build[ ]test[ ]--[ ]OK.+
          ANDK/CPAN-Test-Dummy-Perl5-Make-Features-\\d.+
          make\\S*[ ]test[ ]--[ ]OK)",
          ]
         },
         {
          name => "configure_requires",
          perl_mm_use_default => 1,
          pairs =>
          [
           "test CPAN::Test::Dummy::Perl5::Make::ConfReq" => "test.*-- OK",
           "clean CPAN::Test::Dummy::Perl5::Make::ConfReq" => "clean.*-- OK",
           "clean CPAN::Test::Dummy::Perl5::Make" => "clean.*-- OK",
          ]
         },
         {
          name => "ls",
          perl_mm_use_default => 1,
          requires => [qw(Text::Glob)],
          pairs =>
          [
           "ls ANDK/patches" => "-SADAHIRO-",
           "ls ANDK/patches/" => "-SADAHIRO-",
           "ls ANDK/pa*/*SADA*" => "-SADAHIRO-",
           "ls ANDK/patches/*SADA*" => "-SADAHIRO-",
          ]
         },
        );

    my $cnt;
    for my $session (@SESSIONS) {
        $cnt++;
        if (my $requires = $session->{requires}) {
            for my $req (@$requires) {
                unless ($CPAN::META->has_inst($req)) {
                    $session->{name} .= " [skipping because $req missing]";
                    $session->{pairs} = [];
                }
            }
        }
        for (my $i = 0; $i<$#{$session->{pairs}}; $i+=2) {
            $cnt++;
        }
    }
    plan tests => $cnt
        + 1                     # the MyConfig verification
            ;
    $prompt_re = "\\ncpan(?:[^>]*)> ";
    print "# cnt[$cnt]prompt_re[$prompt_re]\n";
}
is($CPAN::Config->{'7yYQS7'} => 'vGcVJQ');
our $VERBOSE = $ENV{VERBOSE} || 0;
my $devnull = File::Spec->devnull;

for my $si (0..$#SESSIONS) {
    my $session = $SESSIONS[$si];
    my $system = $session->{system} || $default_system;
    # warn "# DEBUG: name[$session->{name}]system[$system]";
    ok($session->{name}, "opening new session '$session->{name}'");
    delete $ENV{PERL_MM_USE_DEFAULT};
    $ENV{PERL_MM_USE_DEFAULT} = 1 if $session->{perl_mm_use_default};
    if ($session->{gets_mirrored_by}) {
        cp _f"t/CPAN/TestMirroredBy", _f"t/dot-cpan/sources/MIRRORED.BY"
            or die "Could not cp t/CPAN/TestMirroredBy over t/dor-cpan/sources/MIRRORED.BY: $!";
        # fix timestamp "bug" (?) on Win32
        utime( (time) x 2, _f"t/dot-cpan/sources/MIRRORED.BY" ); 
    } else {
        unlink _f"t/dot-cpan/sources/MIRRORED.BY";
    }
    open SYSTEM, "| $system 2> $devnull" or die "Could not open '| $system': $!";
    for (my $i = 0; 2*$i < $#{$session->{pairs}}; $i++) {
        my($command) = $session->{pairs}[2*$i];
        print SYSTEM $command, "\n";
    }
    close SYSTEM or mydiag "error while running '$system' on '$session->{name}'";
    my $content = do {local *FH; open FH, "test.out" or die; local $/; <FH>};
    my(@chunks) = split /$prompt_re/, $content;
    # shift @chunks;
    # warn sprintf "# DEBUG: pairs[%d]chunks[%d]", scalar @{$session->{pairs}}, scalar @chunks;
    for (my $i = 0; 2*$i < $#{$session->{pairs}}; $i++) {
        my($command) = $session->{pairs}[2*$i];
        my($expect) = $session->{pairs}[2*$i+1];
        my($actual) = $chunks[$i+1];
        $actual =~ s{t\\00}{t/00}g if ($^O eq 'MSWin32');
        diag("cmd[$command]expect[$expect]actual[$actual]") if $VERBOSE;
        my $success = like($actual,"/$expect/","cmd[$command]");
        if (!$success) {
            require Dumpvalue;
            my $dumper = Dumpvalue->new();
            my $i0 = $i > 4 ? $i-5 : 0;
            warn join "", map { "##$si($session->{name})/$_\:{q[".
                                    $dumper->stringify($session->{pairs}[2*$_]).
                                        "]=>q[".
                                            $dumper->stringify($chunks[$_+1]).
                                                "]}\n" } $i0..$i;
        }
    }
}


# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
