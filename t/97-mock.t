use Test::More tests => 4;

BEGIN { require "t/97-lib_cpan1/CPAN.pm" }

ok( defined &CPAN::shell, "Mock CPAN shell is defined" );
is( CPAN::shell(), 1, "Mock shell returns 1" );

is( exit(), 23, "Mock exit does not exit" );

pass( "Got past the exit" );

