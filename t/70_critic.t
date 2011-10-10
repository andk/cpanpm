use strict;
use warnings;
use File::Spec;
use Test::More;

unless ($ENV{AUTHOR_TEST}) {
    my $msg = 'Test::Perl::Critic only run when AUTHOR_TEST set';
    plan( skip_all => $msg );
}

eval { require Test::Perl::Critic; };

if ( $@ ) {
    my $msg = 'Test::Perl::Critic required to criticise code';
    plan( skip_all => $msg );
}

my $rcfile = File::Spec->catfile( 't', 'perlcriticrc' );
Test::Perl::Critic->import( -profile => $rcfile );
all_critic_ok();



# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
