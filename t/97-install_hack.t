use Test::More qw(no_plan);

my $class  = 'App::Cpan';
my $method = '_stupid_interface_hack_for_non_rtfmers';

use_ok( $class );
can_ok( $class, $method );


@pairs = (
		#before		        after
	[ 'Nothing to nothing',                 [],                        []                 ],
	[ 'Starts with install, then nothing',  [ qw(install) ],           [qw(install)]      ],
	[ 'Starts with install, then module',   [ qw(install Foo::Bar) ],  [qw(Foo::Bar)]     ],
	[ 'Starts with -i, then install',       [ qw(-i install) ],        [ qw(-i install) ] ],
	);


foreach my $pair ( @pairs ) {
	local @ARGV = @{ $pair->[1] };

	$class->$method;

	is_deeply( \@ARGV, $pair->[2], $pair->[0] );
	}
