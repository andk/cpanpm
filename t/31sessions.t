$|=1;
BEGIN {
    unshift @INC, './lib', './t';
    require CPAN;
    require local_utils;

    local_utils::cleanup_dot_cpan();
    local_utils::prepare_dot_cpan();
    CPAN::HandleConfig->load;
    my $yaml_module = CPAN::_yaml_module();
    if ($CPAN::META->has_inst($yaml_module)) {
        print "DEBUG: yaml_module[$yaml_module] loadable\n";
    } else {
        print "1..0 # Skip: no yaml module installed\n";
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

my $default_system = join(" ", map { "\"$_\"" } run_shell_cmd_lit($cwd))." > test.out";

our @SESSIONS =
    (
     {
      name => "first",
      pairs =>
      [
       "dump \$::x=4*6+1" => "= 25;",
       "dump \$::x=40*6+1" => "= 241;",
       "dump \$::x=40*60+1" => "= 2401;",
       "test CPAN::Test::Dummy::Perl5::Make" => "t/00_load\.+ok",
       "get CPAN::Test::Dummy::Perl5::Make" => "Has already been unwrapped",
       "make CPAN::Test::Dummy::Perl5::Make" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made)",
       "test CPAN::Test::Dummy::Perl5::Make" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made.*
                                                  Has.already.been.tested.successfully)",
       "force test CPAN::Test::Dummy::Perl5::Make" => "t/00_load\.+ok",
       "test CPAN::Test::Dummy::Perl5::Build::Fails" => "t/00_load....FAILED",
       "test CPAN::Test::Dummy::Perl5::Build::Fails" => "t/00_load....FAILED",
       "get CPAN::Test::Dummy::Perl5::Build::Fails" => "Has already been unwrapped",
       "make CPAN::Test::Dummy::Perl5::Build::Fails" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made)",
       "force get CPAN::Test::Dummy::Perl5::Build::Fails" => "Checksum for .*/CPAN-Test-Dummy-Perl5-Build-Fails-1.03.tar.gz ok",
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
       "make CPAN::Test::Dummy::Perl5::Build::Fails" => "(?sx:Has.already.been.unwrapped.*
                                                  Has.already.been.made)",
       "test CPAN::Test::Dummy::Perl5::Build::Fails" => "t/00_load....FAILED",
       "o conf dontload_list push YAML" => ".",
       "o conf dontload_list push YAML::Syck" => ".",
       "o conf commit" => "commit: wrote",
      ]
     },
     {
      name => "without_yaml",
      pairs =>
      [
       "get CPAN::Test::Dummy::Perl5::Make" => "(?sx:cannot.parse.*?FTPstats.*
                     CPAN-Test-Dummy-Perl5-Make-1.\\d+/lib/CPAN/Test/Dummy/Perl5/Make.pm.*
                     will.not.store.persistent.state)",
       "make CPAN::Test::Dummy::Perl5::Make" => "Falling back to other methods to determine prerequisites",
       "test CPAN::Test::Dummy::Perl5::Make" => "All tests successful",
      ]
     },
     {
      name => "focussing test",
      pairs =>
      [
       "dump \$::x=4*6+1" => "= 25;",
       "test CPAN::Test::Dummy::Perl5::Make::CircDepeOne" =>
       "(?xs:
  Running.test.for.module.+CPAN::Test::Dummy::Perl5::Make::CircDepeOne.+
  CPAN::Test::Dummy::Perl5::Make::CircDepeThree.+\\[requires\\].+
  CPAN::Test::Dummy::Perl5::Make::CircDepeTwo.+\\[requires\\].+
  CPAN::Test::Dummy::Perl5::Make::CircDepeOne.+\\[requires\\].+
  t/00_load\\.\\.\\.\\.ok.+
  succeeded.but.one.dependency.not.OK.+
  Recursive.dependency.detected
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
my $prompt_re = "cpan> ";
print "DEBUG: cnt[$cnt]\n";
plan tests => $cnt;

for my $session (@SESSIONS) {
    my $system = $session->{system} || $default_system;
    warn "# DEBUG: name[$session->{name}]system[$system]";
    open SYSTEM, "| $system" or die;
    for (my $i = 0; 2*$i < $#{$session->{pairs}}; $i++) {
        my($command) = $session->{pairs}[2*$i];
        my($expect) = $session->{pairs}[2*$i+1];
        print SYSTEM $command, "\n";
    }
    close SYSTEM or mydiag "error while running '$system' on '$session->{name}'";
    my $content = do {local *FH; open FH, "test.out" or die; local $/; <FH>};
    my(@chunks) = split /$prompt_re/, $content;
    shift @chunks;
    for (my $i = 0; 2*$i < $#{$session->{pairs}}; $i++) {
        my($command) = $session->{pairs}[2*$i];
        my($expect) = $session->{pairs}[2*$i+1];
        my($actual) = $chunks[$i];
        like($actual,"/$expect/","command[$command]");
    }
}


# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
