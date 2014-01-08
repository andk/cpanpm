#!/usr/bin/perl
package App::Cpan;
use Test::More 0.95;

BEGIN { 
	local $^W = 0;

	our $class  = 'App::Cpan';
	our $method = '_expand_filename';
	
	use_ok( $class );
	can_ok( $class, $method );
	
	$class->_init_logger;
	}

{
no warnings 'redefine';
*_home_of = sub { 
	my( $user ) = @_;
	$user = 'Buster' unless defined $user;
	$user = 'Buster' if $user =~ /\A\d+\z/; # not the UID
	"/Users/$user" 
	};
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with bad data
subtest 'bad_input' => sub {
	foreach my $input ( undef, 0, '' ) {
		my $result = _expand_filename( $input );
		no warnings 'uninitialized';
		is( $result, $input, "For bad data [$input], output is same as input" );
		}
	};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with no leading tilde
subtest 'no_leading_tilde' => sub {
	foreach my $input ( 'Buster', 'Mimi/Roscoe', 'Ros~coe' ) {
		my $result = _expand_filename( $input );
		is( $result, $input, "For no leading tilde [$input], output is same as input" );
		}
	};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with only tilde
subtest 'tilde_only' => sub {
	my $result = _expand_filename( '~' );
	is( $result, _home_of(), 'For tilde only, output is _home_of' );
	};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with only tilde and one dir
subtest 'tilde_with_name' => sub {
	my $result = _expand_filename( '~foo' );
	is( $result, "/Users/foo", 'For tilde with name, output has that name' );
	};


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test with only tilde and two dirs
subtest 'tilde_name_dir' => sub {
	my $result = _expand_filename( '~foo/bar' );
	is( $result, "/Users/foo/bar", 'For tilde with name and dir, output has name and dir' );
	};

done_testing;

__END__
sub _expand_filename
	{
    my( $path )= @_;
    $logger->debug( "Expanding path $path\n" );
    $path =~ s{\A~([^/]+)?}{
		_home_of( $1 || $> ) || "~$1"
    	}e;
    return $path;
	}
