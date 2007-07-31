# Test CPAN::Distribution objects
# 
# Very, very preliminary API testing, but we have to start somewhere

use strict;

use File::Copy qw(cp);
use File::Path qw(rmtree mkpath);

use lib "inc";
use lib "t";
use local_utils;

# prepare local CPAN
local_utils::cleanup_dot_cpan();
local_utils::prepare_dot_cpan();
# and be sure to clean it up
END{ local_utils::cleanup_dot_cpan(); }

use Test::More;
use File::Basename qw/basename/;

my @tarball_suffixes = qw(
        .tgz
        .tbz
        .tar.gz
        .tar.bz2
        .tar.Z
        .zip
);
        

plan tests => 1 + @tarball_suffixes;

require_ok( "CPAN" );

#--------------------------------------------------------------------------#
# base_id() testing
#--------------------------------------------------------------------------#

{
        my $dist_base = "Bogus-Module-1.234";
        for my $s ( @tarball_suffixes ) {
                my $dist = CPAN::Distribution->new(
                        ID => "D/DA/DAGOLDEN/$dist_base$s"
                );
                is( $dist->base_id, $dist_base, "base_id() strips $s" );
        }
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
