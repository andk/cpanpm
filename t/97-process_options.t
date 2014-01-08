#!/usr/bin/perl
use Test::More tests => 4;

BEGIN {  *CORE::GLOBAL::exit = sub { 23 } };

BEGIN { 
	local $^W = 0;

	our $class  = 'App::Cpan';
	our $method = '_process_options';
	
	use_ok( $class );
	can_ok( $class, $method );
	
	require "t/lib_cpan1/CPAN.pm";
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with no options
{
local @ARGV = ();

is( $class->$method(), 23, "No arguments calls shell branch" );
pass( "Got past the exit" );
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
