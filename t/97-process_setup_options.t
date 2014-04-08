#!/usr/bin/perl

use Test::More 'no_plan';

my $class  = 'App::Cpan';
my $method = '_process_options';

use_ok( $class );
can_ok( $class, $method );

{
require "t/97-lib_cpan1/CPAN.pm";

ok( defined &CPAN::shell, "Mock CPAN shell is defined" );
is( CPAN::shell(), 1, "Mock shell returns 1" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with no options
{
local @ARGV = ();

# not yet tested
}

}
