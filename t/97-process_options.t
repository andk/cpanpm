use Test::More tests => 4;

BEGIN {  *CORE::GLOBAL::exit = sub { 23 } };

BEGIN {
	local $^W = 0;

	our $class  = 'App::Cpan';
	our $method = '_process_options';

	use_ok( $class );
	can_ok( $class, $method );

	require "t/97-lib_cpan1/CPAN.pm";
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with no options
{
local @ARGV = ();

is( $class->$method(), 23, "No arguments calls shell branch" );
pass( "Got past the exit" );
}
