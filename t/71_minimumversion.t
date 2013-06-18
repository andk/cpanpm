use strict;
use warnings;
use File::Spec;
use Test::More;

unless ($ENV{AUTHOR_TEST}) {
    my $msg = 'running MinimumVersion test only run when AUTHOR_TEST set';
    plan( skip_all => $msg );
}

eval { require Test::MinimumVersion; };

if ( $@ ) {

    my $msg = 'Test::MinimumVersion{::Fast,} required for this test';
    plan( skip_all => $msg );
} else {
    diag "Found Test::MinimumVersion v $Test::MinimumVersion::VERSION";
    import Test::MinimumVersion;
}

all_minimum_version_from_metayml_ok({ paths => [qw(lib scripts t)]});



# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
