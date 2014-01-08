#!/usr/bin/perl

use Test::More 'no_plan';

my $class  = 'App::Cpan';
my $method = '_process_options';

use_ok( $class );
can_ok( $class, $method );

{
require "t/lib_cpan1/CPAN.pm";

ok( defined &CPAN::shell, "Mock CPAN shell is defined" );
is( CPAN::shell(), 1, "Mock shell returns 1" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with no options
{
local @ARGV = ();

# not yet tested
}

}


__END__
sub _process_options
	{
	my %options;
	
	# if no arguments, just drop into the shell
	if( 0 == @ARGV ) { CPAN::shell(); exit 0 }

	Getopt::Std::getopts(
		join( '', 
			map {
				$Method_table{ $_ }[ $Method_table_index{takes_args} ] ? "$_:" : $_
				} @option_order 
			), 
				
		\%options 
		);
		
	\%options;
	}
