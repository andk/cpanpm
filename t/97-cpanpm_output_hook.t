use strict;
use warnings;

use Test::More tests => 60;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
my $CPAN = 'CPAN::Shell';

my $class = 'App::Cpan';
use_ok( $class );
can_ok( $class, $_ ) for (
	'_hook_into_CPANpm_report',
	'_init_logger',
	'_clear_cpanpm_output',
	'_get_cpanpm_output',
	'_get_cpanpm_last_line',
	'_cpanpm_output_indicates_failure',
	'_cpanpm_output_indicates_success',
	'_cpanpm_output_is_vague',
	);


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
$class->_hook_into_CPANpm_report;
$class->_init_logger;

{
no warnings 'redefine';
no warnings 'once';

*CPAN::Shell::print_ornamented = sub { 37 };

is( CPAN::Shell->print_ornamented, 37, "Mocked print_ornamented" );
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
my_clear_and_get( qw(myprint Buster) );
my_clear_and_get( qw(mywarn Mimi) );


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
{
_clear();

local $CPAN::Config;
$CPAN::Config->{colorize_print} = 1; # just to get conditional coverage
$CPAN::Config->{colorize_warn}  = 1; # just to get conditional coverage

my @messages = qw(Dog Bird Cat);
foreach my $message ( @messages )
	{
	$CPAN->myprint( $message );
	$CPAN->mywarn( $message );
	}
is( $class->_get_cpanpm_output, join '', map { $_, $_ } @messages );

_clear();
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
{
_clear();

my @messages = qw(Dog Bird Cat Crow);
foreach my $message ( @messages )
	{
	$CPAN->myprint( "$message\n" );
	}
is( $class->_get_cpanpm_last_line, "$messages[-1]\n", 'Got right last line' );

_clear();
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
{
my @lines = ( # -1 is vague, 0 is failure, 1 is success
	[ 0, 'make: *** [install] Error 13' ],
	[ 0, "make: *** [pure_site_install] Error 13" ],
	[ 0, "make: *** No rule to make target `install'.  Stop." ],
	[ 0, "  make test had returned bad status, won\'t install without force" ],
	[ 0, "  Make had some problems, won\'t install" ],

	[ 1, "  /usr/bin/make install  -- OK\n, will not store persistent state",   "  /usr/bin/make install  -- OK\n" ],
	[ 1, "  /usr/bin/make install  -- OK\n//hint// Don't do that!",   "  /usr/bin/make install  -- OK\n" ],
	[ 1, 'Result: PASS' ],
	[ 1, "  /usr/bin/make install  -- OK" ],
	);

_clear();

foreach my $pair ( @lines ) {
	my( $rc, $message, $last_good_line ) = @$pair;
	$last_good_line = $message unless defined $last_good_line;

	$CPAN->_clear_cpanpm_output;
	$CPAN->myprint( $message );

	my $last_line = $class->_get_cpanpm_last_line();
	is( $last_line, $last_good_line, 'Last line is last message' );

	is( $class->_cpanpm_output_indicates_failure, $rc ? undef : 1,
		"[$message] failure?" );
	is( $class->_cpanpm_output_indicates_success, $rc ? 1 : undef,
		"[$message] success?" );
	}


_clear();
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
{
my $message = <<'HERE';
Result: FAIL
  D:/Workspace/CI/DRW-Perl/DRW-Module-Build/distributions/DRW-Module-Build/.
  C:\strawberry\\perl\\bin\\perl.exe ./Build test -- NOT OK
//hint// to see the cpan-testers results for installing this module, try:
  reports D:/Workspace/CI/DRW-Perl/DRW-Module-Build/distributions/DRW-Module-Build/.
Directory 'D:/Workspace/CI/DRW-Perl/DRW-Module-Build/distributions/DRW-Module-Build/.' not below D:\Workspace\drwperl\build, will not store persistent state
HERE

$CPAN->_clear_cpanpm_output;
$CPAN->myprint( $message );

my $last_line = $class->_get_cpanpm_last_line();
like( $last_line, qr/NOT OK/, 'Last line is NOT OK line' );

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub my_clear_and_get {
	my( $method, $message ) = @_;
	can_ok( $CPAN, $method );

	_clear();

	$CPAN->$method( $message );
	is( $class->_get_cpanpm_output, $message,
		'_get_cpanpm_output returns the message sent to myprint' );
	}

sub _clear {
	is( $class->_clear_cpanpm_output, '', 'Clear returns empty string' );
	is( $class->_get_cpanpm_output, '', 'Get returns empty string right after clear' );
	}
