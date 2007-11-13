$|=1;
BEGIN {
    unshift @INC, './lib', './t';

    require local_utils;
    local_utils::cleanup_dot_cpan();
    local_utils::prepare_dot_cpan();
    require CPAN::MyConfig;
    require CPAN;

    CPAN::HandleConfig->load;
    my $yaml_module = CPAN::_yaml_module();
    my $exit_message;
    # local $CPAN::Be_Silent = 1; # not the official interface!!!
    if ($CPAN::META->has_inst($yaml_module)) {
        print "# yaml_module[$yaml_module] loadable\n";
    } else {
        $exit_message = "No yaml module installed";
    }
    if ($CPAN::META->has_inst("Module::Build")) {
        print "# Module::Build loadable\n";
    } else {
        $exit_message = "Module::Build not installed";
    }
  TABU: for my $tabu (qw(
                         CPAN::Test::Dummy::Perl5::Make
                         CPAN::Test::Dummy::Perl5::Make::ConfReq
                         CPAN::Test::Dummy::Perl5::Build::Fails
                         CPAN::Test::Dummy::Perl5::Make::CircDepeOne
                         CPAN::Test::Dummy::Perl5::Make::CircDepeTwo
                         CPAN::Test::Dummy::Perl5::Make::CircDepeThree
                         CPAN::Test::Dummy::Perl5::Make::UnsatPrereq
                        )) {
        if ($CPAN::META->has_inst($tabu)) {
            $exit_message = "Found module '$tabu' installed. Cannot run this test.";
            last TABU;
        }
    }
    if ($exit_message) {
        $|=1;
        print "1..0 # Skip: $exit_message\n";
        eval "require POSIX; 1" and POSIX::_exit(0);
    }
}

use strict;
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
my $cwd = Cwd::cwd;

my $VERBOSE = 0;
#  2>&1 is no solution. I intertwingled them, I missed a few "ok"
my $default_system = join(" ", map { "\"$_\"" } run_shell_cmd_lit($cwd))." > test.out";


our @SESSIONS =
    (
     {
      name => "configure_requires",
      pairs =>
      [
       "test CPAN::Test::Dummy::Perl5::Make::ConfReq" => "test.*-- OK",
       "clean CPAN::Test::Dummy::Perl5::Make::ConfReq" => "clean.*-- OK",
       "clean CPAN::Test::Dummy::Perl5::Make" => "clean.*-- OK",
      ]
     },
     {
      name => "the historically first",
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
                         |Checksum.for.*/CPAN-Test-Dummy-Perl5-Build-Fails-1.03.tar.gz.ok)",
       "o conf build_dir_reuse 1" => "build_dir_reuse",
       "o conf commit" => "commit: wrote",
      ]
     },
     {
      name => "second",
      pairs =>
      [
       "get CPAN::Test::Dummy::Perl5::Make" => "Has already been unwrapped",
       "make CPAN::Test::Dummy::Perl5::Make" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made)",
       "test CPAN::Test::Dummy::Perl5::Make" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made.*
                                                  Has.already.been.tested.successfully)",
       "get CPAN::Test::Dummy::Perl5::Build::Fails" => "Has already been unwrapped",
       "make CPAN::Test::Dummy::Perl5::Build::Fails" => "Has.already.been.unwrapped",
       "test CPAN::Test::Dummy::Perl5::Build::Fails" => "(?i:t/00_load.+FAILED)",
       "o conf dontload_list push YAML" => ".",
       "o conf dontload_list push YAML::Syck" => ".",
       "o conf commit" => "commit: wrote",
      ]
     },
     {
      name => "without_yaml", # because we disabled it with dontload_list above
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
      pairs =>
      [
       "dump \$::x=4*6+1" => "= 25;",
       "test CPAN::Test::Dummy::Perl5::Make::UnsatPrereq" =>
       "(?xs:
  Warning:.+?
  Prerequisite.+?
  CPAN::Test::Dummy::Perl5::Make.+?
  99999999.99.+?
  not[ ]available[ ]according[ ]to[ ]the[ ]indexes
)",
      ],
     },
    );

my $cnt;
for my $session (@SESSIONS) {
    for (my $i = 0; $i<$#{$session->{pairs}}; $i+=2) {
        $cnt++;
    }
}
my $prompt_re = "\\ncpan(?:[^>]*)> ";
print "# cnt[$cnt]prompt_re[$prompt_re]\n";
plan tests => $cnt
    + 1 # the MyConfig verification
    ;
is($CPAN::Config->{'7yYQS7'} => 'vGcVJQ');
$ENV{PERL_MM_USE_DEFAULT} = 1;

for my $session (@SESSIONS) {
    my $system = $session->{system} || $default_system;
    # warn "# DEBUG: name[$session->{name}]system[$system]";
    open SYSTEM, "| $system" or die;
    for (my $i = 0; 2*$i < $#{$session->{pairs}}; $i++) {
        my($command) = $session->{pairs}[2*$i];
        my($expect) = $session->{pairs}[2*$i+1];
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
        diag("command[$command]expect[$expect]actual[$actual]") if $VERBOSE;
        unless (like($actual,"/$expect/","command[$command]")) {
            require Dumpvalue;
            my $dumper = Dumpvalue->new();
            my $i0 = $i > 4 ? $i-5 : 0;
            warn join "", "# ", map { "[".$dumper->stringify($_)."]" } @chunks[$i0..$i];
        }
    }
}


# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
