package Test::Builder;

use 5.004;

# $^C was only introduced in 5.005-ish.  We do this to prevent
# use of uninitialized value warnings in older perls.
$^C ||= 0;

use strict;
use vars qw($VERSION $CLASS);
$VERSION = '0.17';
$CLASS = __PACKAGE__;

my $IsVMS = $^O eq 'VMS';

# Make Test::Builder thread-safe for ithreads.
BEGIN {
    use Config;
    if( $] >= 5.008 && $Config{useithreads} ) {
        require threads;
        require threads::shared;
        threads::shared->import;
    }
    else {
        *share = sub { 0 };
        *lock  = sub { 0 };
    }
}

use vars qw($Level);
my($Test_Died) = 0;
my($Have_Plan) = 0;
my $Original_Pid = $$;
my $Curr_Test = 0;      share($Curr_Test);
my @Test_Results = ();  share(@Test_Results);
my @Test_Details = ();  share(@Test_Details);



my $Test;
sub new {
    my($class) = shift;
    $Test ||= bless ['Move along, nothing to see here'], $class;
    return $Test;
}


my $Exported_To;
sub exported_to {
    my($self, $pack) = @_;

    if( defined $pack ) {
        $Exported_To = $pack;
    }
    return $Exported_To;
}

sub plan {
    my($self, $cmd, $arg) = @_;

    return unless $cmd;

    if( $Have_Plan ) {
        die sprintf "You tried to plan twice!  Second plan at %s line %d\n",
          ($self->caller)[1,2];
    }

    if( $cmd eq 'no_plan' ) {
        $self->no_plan;
    }
    elsif( $cmd eq 'skip_all' ) {
        return $self->skip_all($arg);
    }
    elsif( $cmd eq 'tests' ) {
        if( $arg ) {
            return $self->expected_tests($arg);
        }
        elsif( !defined $arg ) {
            die "Got an undefined number of tests.  Looks like you tried to ".
                "say how many tests you plan to run but made a mistake.\n";
        }
        elsif( !$arg ) {
            die "You said to run 0 tests!  You've got to run something.\n";
        }
    }
    else {
        require Carp;
        my @args = grep { defined } ($cmd, $arg);
        Carp::croak("plan() doesn't understand @args");
    }

    return 1;
}


my $Expected_Tests = 0;
sub expected_tests {
    my($self, $max) = @_;

    if( defined $max ) {
        $Expected_Tests = $max;
        $Have_Plan      = 1;

        $self->_print("1..$max\n") unless $self->no_header;
    }
    return $Expected_Tests;
}



my($No_Plan) = 0;
sub no_plan {
    $No_Plan    = 1;
    $Have_Plan  = 1;
}


sub has_plan {
	return($Expected_Tests) if $Expected_Tests;
	return('no_plan') if $No_Plan;
	return(undef);
};



my $Skip_All = 0;
sub skip_all {
    my($self, $reason) = @_;

    my $out = "1..0";
    $out .= " # Skip $reason" if $reason;
    $out .= "\n";

    $Skip_All = 1;

    $self->_print($out) unless $self->no_header;
    exit(0);
}


sub ok {
    my($self, $test, $name) = @_;

    # $test might contain an object which we don't want to accidentally
    # store, so we turn it into a boolean.
    $test = $test ? 1 : 0;

    unless( $Have_Plan ) {
        require Carp;
        Carp::croak("You tried to run a test without a plan!  Gotta have a plan.");
    }

    lock $Curr_Test;
    $Curr_Test++;

    $self->diag(<<ERR) if defined $name and $name =~ /^[\d\s]+$/;
    You named your test '$name'.  You shouldn't use numbers for your test names.
    Very confusing.
ERR

    my($pack, $file, $line) = $self->caller;

    my $todo = $self->todo($pack);

    my $out;
    my $result = {};
    share($result);

    unless( $test ) {
        $out .= "not ";
        @$result{ 'ok', 'actual_ok' } = ( ( $todo ? 1 : 0 ), 0 );
    }
    else {
        @$result{ 'ok', 'actual_ok' } = ( 1, $test );
    }

    $out .= "ok";
    $out .= " $Curr_Test" if $self->use_numbers;

    if( defined $name ) {
        $name =~ s|#|\\#|g;     # # in a name can confuse Test::Harness.
        $out   .= " - $name";
        $result->{name} = $name;
    }
    else {
        $result->{name} = '';
    }

    if( $todo ) {
        my $what_todo = $todo;
        $out   .= " # TODO $what_todo";
        $result->{reason} = $what_todo;
        $result->{type}   = 'todo';
    }
    else {
        $result->{reason} = '';
        $result->{type}   = '';
    }

    $Test_Results[$Curr_Test-1] = $result;
    $out .= "\n";

    $self->_print($out);

    unless( $test ) {
        my $msg = $todo ? "Failed (TODO)" : "Failed";
        $self->diag("    $msg test ($file at line $line)\n");
    } 

    return $test ? 1 : 0;
}


sub is_eq {
    my($self, $got, $expect, $name) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;

        $self->ok($test, $name);
        $self->_is_diag($got, 'eq', $expect) unless $test;
        return $test;
    }

    return $self->cmp_ok($got, 'eq', $expect, $name);
}

sub is_num {
    my($self, $got, $expect, $name) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;

        $self->ok($test, $name);
        $self->_is_diag($got, '==', $expect) unless $test;
        return $test;
    }

    return $self->cmp_ok($got, '==', $expect, $name);
}

sub _is_diag {
    my($self, $got, $type, $expect) = @_;

    foreach my $val (\$got, \$expect) {
        if( defined $$val ) {
            if( $type eq 'eq' ) {
                # quote and force string context
                $$val = "'$$val'"
            }
            else {
                # force numeric context
                $$val = $$val+0;
            }
        }
        else {
            $$val = 'undef';
        }
    }

    return $self->diag(sprintf <<DIAGNOSTIC, $got, $expect);
         got: %s
    expected: %s
DIAGNOSTIC

}    


sub isnt_eq {
    my($self, $got, $dont_expect, $name) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $dont_expect ) {
        # undef only matches undef and nothing else
        my $test = defined $got || defined $dont_expect;

        $self->ok($test, $name);
        $self->_cmp_diag('ne', $got, $dont_expect) unless $test;
        return $test;
    }

    return $self->cmp_ok($got, 'ne', $dont_expect, $name);
}

sub isnt_num {
    my($self, $got, $dont_expect, $name) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $dont_expect ) {
        # undef only matches undef and nothing else
        my $test = defined $got || defined $dont_expect;

        $self->ok($test, $name);
        $self->_cmp_diag('!=', $got, $dont_expect) unless $test;
        return $test;
    }

    return $self->cmp_ok($got, '!=', $dont_expect, $name);
}



sub like {
    my($self, $this, $regex, $name) = @_;

    local $Level = $Level + 1;
    $self->_regex_ok($this, $regex, '=~', $name);
}

sub unlike {
    my($self, $this, $regex, $name) = @_;

    local $Level = $Level + 1;
    $self->_regex_ok($this, $regex, '!~', $name);
}



sub maybe_regex {
	my ($self, $regex) = @_;
    my $usable_regex = undef;
    if( ref $regex eq 'Regexp' ) {
        $usable_regex = $regex;
    }
    # Check if it looks like '/foo/'
    elsif( my($re, $opts) = $regex =~ m{^ /(.*)/ (\w*) $ }sx ) {
        $usable_regex = length $opts ? "(?$opts)$re" : $re;
    };
    return($usable_regex)
};

sub _regex_ok {
    my($self, $this, $regex, $cmp, $name) = @_;

    local $Level = $Level + 1;

    my $ok = 0;
    my $usable_regex = $self->maybe_regex($regex);
    unless (defined $usable_regex) {
        $ok = $self->ok( 0, $name );
        $self->diag("    '$regex' doesn't look much like a regex to me.");
        return $ok;
    }

    {
        local $^W = 0;
        my $test = $this =~ /$usable_regex/ ? 1 : 0;
        $test = !$test if $cmp eq '!~';
        $ok = $self->ok( $test, $name );
    }

    unless( $ok ) {
        $this = defined $this ? "'$this'" : 'undef';
        my $match = $cmp eq '=~' ? "doesn't match" : "matches";
        $self->diag(sprintf <<DIAGNOSTIC, $this, $match, $regex);
                  %s
    %13s '%s'
DIAGNOSTIC

    }

    return $ok;
}


sub cmp_ok {
    my($self, $got, $type, $expect, $name) = @_;

    my $test;
    {
        local $^W = 0;
        local($@,$!);   # don't interfere with $@
                        # eval() sometimes resets $!
        $test = eval "\$got $type \$expect";
    }
    local $Level = $Level + 1;
    my $ok = $self->ok($test, $name);

    unless( $ok ) {
        if( $type =~ /^(eq|==)$/ ) {
            $self->_is_diag($got, $type, $expect);
        }
        else {
            $self->_cmp_diag($got, $type, $expect);
        }
    }
    return $ok;
}

sub _cmp_diag {
    my($self, $got, $type, $expect) = @_;
    
    $got    = defined $got    ? "'$got'"    : 'undef';
    $expect = defined $expect ? "'$expect'" : 'undef';
    return $self->diag(sprintf <<DIAGNOSTIC, $got, $type, $expect);
    %s
        %s
    %s
DIAGNOSTIC
}


sub BAILOUT {
    my($self, $reason) = @_;

    $self->_print("Bail out!  $reason");
    exit 255;
}


sub skip {
    my($self, $why) = @_;
    $why ||= '';

    unless( $Have_Plan ) {
        require Carp;
        Carp::croak("You tried to run tests without a plan!  Gotta have a plan.");
    }

    lock($Curr_Test);
    $Curr_Test++;

    my %result;
    share(%result);
    %result = (
        'ok'      => 1,
        actual_ok => 1,
        name      => '',
        type      => 'skip',
        reason    => $why,
    );
    $Test_Results[$Curr_Test-1] = \%result;

    my $out = "ok";
    $out   .= " $Curr_Test" if $self->use_numbers;
    $out   .= " # skip $why\n";

    $Test->_print($out);

    return 1;
}



sub todo_skip {
    my($self, $why) = @_;
    $why ||= '';

    unless( $Have_Plan ) {
        require Carp;
        Carp::croak("You tried to run tests without a plan!  Gotta have a plan.");
    }

    lock($Curr_Test);
    $Curr_Test++;

    my %result;
    share(%result);
    %result = (
        'ok'      => 1,
        actual_ok => 0,
        name      => '',
        type      => 'todo_skip',
        reason    => $why,
    );

    $Test_Results[$Curr_Test-1] = \%result;

    my $out = "not ok";
    $out   .= " $Curr_Test" if $self->use_numbers;
    $out   .= " # TODO & SKIP $why\n";

    $Test->_print($out);

    return 1;
}



sub level {
    my($self, $level) = @_;

    if( defined $level ) {
        $Level = $level;
    }
    return $Level;
}

$CLASS->level(1);



my $Use_Nums = 1;
sub use_numbers {
    my($self, $use_nums) = @_;

    if( defined $use_nums ) {
        $Use_Nums = $use_nums;
    }
    return $Use_Nums;
}


my($No_Header, $No_Ending) = (0,0);
sub no_header {
    my($self, $no_header) = @_;

    if( defined $no_header ) {
        $No_Header = $no_header;
    }
    return $No_Header;
}

sub no_ending {
    my($self, $no_ending) = @_;

    if( defined $no_ending ) {
        $No_Ending = $no_ending;
    }
    return $No_Ending;
}



sub diag {
    my($self, @msgs) = @_;
    return unless @msgs;

    # Prevent printing headers when compiling (i.e. -c)
    return if $^C;

    # Escape each line with a #.
    foreach (@msgs) {
        $_ = 'undef' unless defined;
        s/^/# /gms;
    }

    push @msgs, "\n" unless $msgs[-1] =~ /\n\Z/;

    local $Level = $Level + 1;
    my $fh = $self->todo ? $self->todo_output : $self->failure_output;
    local($\, $", $,) = (undef, ' ', '');
    print $fh @msgs;

    return 0;
}


sub _print {
    my($self, @msgs) = @_;

    # Prevent printing headers when only compiling.  Mostly for when
    # tests are deparsed with B::Deparse
    return if $^C;

    local($\, $", $,) = (undef, ' ', '');
    my $fh = $self->output;

    # Escape each line after the first with a # so we don't
    # confuse Test::Harness.
    foreach (@msgs) {
        s/\n(.)/\n# $1/sg;
    }

    push @msgs, "\n" unless $msgs[-1] =~ /\n\Z/;

    print $fh @msgs;
}



my($Out_FH, $Fail_FH, $Todo_FH);
sub output {
    my($self, $fh) = @_;

    if( defined $fh ) {
        $Out_FH = _new_fh($fh);
    }
    return $Out_FH;
}

sub failure_output {
    my($self, $fh) = @_;

    if( defined $fh ) {
        $Fail_FH = _new_fh($fh);
    }
    return $Fail_FH;
}

sub todo_output {
    my($self, $fh) = @_;

    if( defined $fh ) {
        $Todo_FH = _new_fh($fh);
    }
    return $Todo_FH;
}

sub _new_fh {
    my($file_or_fh) = shift;

    my $fh;
    unless( UNIVERSAL::isa($file_or_fh, 'GLOB') ) {
        $fh = do { local *FH };
        open $fh, ">$file_or_fh" or 
            die "Can't open test output log $file_or_fh: $!";
    }
    else {
        $fh = $file_or_fh;
    }

    return $fh;
}

unless( $^C ) {
    # We dup STDOUT and STDERR so people can change them in their
    # test suites while still getting normal test output.
    open(TESTOUT, ">&STDOUT") or die "Can't dup STDOUT:  $!";
    open(TESTERR, ">&STDERR") or die "Can't dup STDERR:  $!";

    # Set everything to unbuffered else plain prints to STDOUT will
    # come out in the wrong order from our own prints.
    _autoflush(\*TESTOUT);
    _autoflush(\*STDOUT);
    _autoflush(\*TESTERR);
    _autoflush(\*STDERR);

    $CLASS->output(\*TESTOUT);
    $CLASS->failure_output(\*TESTERR);
    $CLASS->todo_output(\*TESTOUT);
}

sub _autoflush {
    my($fh) = shift;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;
}



sub current_test {
    my($self, $num) = @_;

    lock($Curr_Test);
    if( defined $num ) {
        unless( $Have_Plan ) {
            require Carp;
            Carp::croak("Can't change the current test number without a plan!");
        }

        $Curr_Test = $num;
        if( $num > @Test_Results ) {
            my $start = @Test_Results ? $#Test_Results + 1 : 0;
            for ($start..$num-1) {
                my %result;
                share(%result);
                %result = ( ok        => 1, 
                            actual_ok => undef, 
                            reason    => 'incrementing test number', 
                            type      => 'unknown', 
                            name      => undef 
                          );
                $Test_Results[$_] = \%result;
            }
        }
    }
    return $Curr_Test;
}



sub summary {
    my($self) = shift;

    return map { $_->{'ok'} } @Test_Results;
}


sub details {
    return @Test_Results;
}


sub todo {
    my($self, $pack) = @_;

    $pack = $pack || $self->exported_to || $self->caller(1);

    no strict 'refs';
    return defined ${$pack.'::TODO'} ? ${$pack.'::TODO'}
                                     : 0;
}


sub caller {
    my($self, $height) = @_;
    $height ||= 0;

    my @caller = CORE::caller($self->level + $height + 1);
    return wantarray ? @caller : $caller[0];
}

sub _sanity_check {
    _whoa($Curr_Test < 0,  'Says here you ran a negative number of tests!');
    _whoa(!$Have_Plan and $Curr_Test, 
          'Somehow your tests ran without a plan!');
    _whoa($Curr_Test != @Test_Results,
          'Somehow you got a different number of results than tests ran!');
}


sub _whoa {
    my($check, $desc) = @_;
    if( $check ) {
        die <<WHOA;
WHOA!  $desc
This should never happen!  Please contact the author immediately!
WHOA
    }
}


sub _my_exit {
    $? = $_[0];

    return 1;
}



$SIG{__DIE__} = sub {
    # We don't want to muck with death in an eval, but $^S isn't
    # totally reliable.  5.005_03 and 5.6.1 both do the wrong thing
    # with it.  Instead, we use caller.  This also means it runs under
    # 5.004!
    my $in_eval = 0;
    for( my $stack = 1;  my $sub = (CORE::caller($stack))[3];  $stack++ ) {
        $in_eval = 1 if $sub =~ /^\(eval\)/;
    }
    $Test_Died = 1 unless $in_eval;
};

sub _ending {
    my $self = shift;

    _sanity_check();

    # Don't bother with an ending if this is a forked copy.  Only the parent
    # should do the ending.
    do{ _my_exit($?) && return } if $Original_Pid != $$;

    # Bailout if plan() was never called.  This is so
    # "require Test::Simple" doesn't puke.
    do{ _my_exit(0) && return } if !$Have_Plan && !$Test_Died;

    # Figure out if we passed or failed and print helpful messages.
    if( @Test_Results ) {
        # The plan?  We have no plan.
        if( $No_Plan ) {
            $self->_print("1..$Curr_Test\n") unless $self->no_header;
            $Expected_Tests = $Curr_Test;
        }

        # 5.8.0 threads bug.  Shared arrays will not be auto-extended 
        # by a slice.  Worse, we have to fill in every entry else
        # we'll get an "Invalid value for shared scalar" error
        for my $idx ($#Test_Results..$Expected_Tests-1) {
            my %empty_result = ();
            share(%empty_result);
            $Test_Results[$idx] = \%empty_result
              unless defined $Test_Results[$idx];
        }

        my $num_failed = grep !$_->{'ok'}, @Test_Results[0..$Expected_Tests-1];
        $num_failed += abs($Expected_Tests - @Test_Results);

        if( $Curr_Test < $Expected_Tests ) {
            $self->diag(<<"FAIL");
Looks like you planned $Expected_Tests tests but only ran $Curr_Test.
FAIL
        }
        elsif( $Curr_Test > $Expected_Tests ) {
            my $num_extra = $Curr_Test - $Expected_Tests;
            $self->diag(<<"FAIL");
Looks like you planned $Expected_Tests tests but ran $num_extra extra.
FAIL
        }
        elsif ( $num_failed ) {
            $self->diag(<<"FAIL");
Looks like you failed $num_failed tests of $Expected_Tests.
FAIL
        }

        if( $Test_Died ) {
            $self->diag(<<"FAIL");
Looks like your test died just after $Curr_Test.
FAIL

            _my_exit( 255 ) && return;
        }

        _my_exit( $num_failed <= 254 ? $num_failed : 254  ) && return;
    }
    elsif ( $Skip_All ) {
        _my_exit( 0 ) && return;
    }
    elsif ( $Test_Died ) {
        $self->diag(<<'FAIL');
Looks like your test died before it could output anything.
FAIL
    }
    else {
        $self->diag("No tests run!\n");
        _my_exit( 255 ) && return;
    }
}

END {
    $Test->_ending if defined $Test and !$Test->no_ending;
}


1;
