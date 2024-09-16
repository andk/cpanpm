#!/usr/bin/perl

use Test::More;
END { done_testing() }

my $class  = 'App::Cpan';
my $method = '_process_options';

use_ok( $class );
can_ok( $class, $method );

{
require "./t/97-lib_cpan1/CPAN.pm";

ok( defined &CPAN::shell, "Mock CPAN shell is defined" );
is( CPAN::shell(), 1, "Mock shell returns 1" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with no options
subtest cpan_opts => sub {
	local $ENV{CPAN_OPTS} = '-T';
	local @ARGV = qw(Some::Module);

	my $options  = $class->_process_options;
	ok( $options->{T}, 'options include -T from CPAN_OPTS' );
	};

subtest dash_g_in_argv => sub {
	delete local $ENV{CPAN_OPTS};
	local @ARGV = qw(-g Some::Module);

	my $options  = $class->_process_options;
	ok( $options->{g}, 'options include -T from CPAN_OPTS' );
	};

}
