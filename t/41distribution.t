# Test CPAN::Distribution objects
# 
# Very, very preliminary API testing, but we have to start somewhere

use strict;

use Cwd qw(cwd);
use File::Copy qw(cp);
use File::Path qw(rmtree mkpath);
use File::Temp qw(tempdir);
use File::Spec::Functions qw/catdir catfile/;
use File::Basename qw/basename/;

use lib "inc";
use lib "t";
use local_utils;

# prepare local CPAN
local_utils::cleanup_dot_cpan();
local_utils::prepare_dot_cpan();
# and be sure to clean it up
END{ local_utils::cleanup_dot_cpan(); }

use Test::More;

my (@tarball_suffixes, @meta_yml_tests); # defined later in BEGIN blocks

plan tests => 1 + @tarball_suffixes + 3 * @meta_yml_tests;

require_ok( "CPAN" );

#--------------------------------------------------------------------------#
# base_id() testing
#--------------------------------------------------------------------------#

BEGIN {
    @tarball_suffixes = qw(
        .tgz
        .tbz
        .tar.gz
        .tar.bz2
        .tar.Z
        .zip
    );
}     

{
        my $dist_base = "Bogus-Module-1.234";
        for my $s ( @tarball_suffixes ) {
                my $dist = CPAN::Distribution->new(
                        ID => "D/DA/DAGOLDEN/$dist_base$s"
                );
                is( $dist->base_id, $dist_base, "base_id() strips $s" );
        }
}

#--------------------------------------------------------------------------#
# read_meta() testing
#--------------------------------------------------------------------------#

BEGIN {
    @meta_yml_tests = (
        {
            label => 'no META.yml',
            copies => [],
            requires => undef,
        },
        {
            label => 'dynamic META.yml',
            copies => [ 'META-dynamic.yml', 'META.yml' ],
            requires => undef,
        },
        {
            label => 'non-dynamic META.yml',
            copies => [ 'META-static.yml', 'META.yml' ],
            requires => { 'File::Spec' => 0.87 },
        },
        {
            label => 'dynamic META.yml plus MYMETA.yml',
            copies => [ 
                'META-dynamic.yml', 'META.yml',
                'META-dynamic.yml', 'MYMETA.yml',
            ],
            requires => { 'File::Spec' => 0.87 },
        },
    );
}

{
    for my $case ( @meta_yml_tests ) {
        my $yaml;
        my $label = $case->{label};
        my $tempdir = tempdir( "t/41distributionXXXX", CLEANUP => 1 );

        # dummy distribution
        my $dist = CPAN::Distribution->new(
            ID => "D/DA/DAGOLDEN/Bogus-Module-1.234"
        );
        $dist->{build_dir} = $tempdir;    

        # copy files
        if ( $case->{copies} ) {
            while (@{$case->{copies}}) {
                my ($from, $to) = splice(@{$case->{copies}},0,2);
                cp catfile( qw/t data/, $from) => catfile($tempdir, $to); 
            }
        }

        # check read_yaml
        $yaml = $dist->read_yaml;
        if ( defined $case->{requires} ) {
            my $type = ref $yaml;
            is( $type, 'HASH', "$label\: read_yaml returns HASH ref" );
            is( ref $dist->read_yaml, $type, "$label\: repeat read_yaml is same" );
            if ( $type ) {
                my $mismatch = 0;
                for my $k ( keys %{ $case->{requires} } ) {
                    $mismatch++ unless $yaml->{requires}{$k} == $case->{requires}{$k};
                }
                ok( $mismatch == 0, "$label\: found expected requirements" );
            }
            else {
                fail( "$label\: no requirements available\n" );
            }
        }
        else {
            is( $yaml, undef, "$label\: read_yaml returns undef");
            is( $dist->read_yaml, undef, "$label\: repeat read_yaml returns undef");
            pass( "$label\: no requirement checks apply" );
        }
    }
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
# vi: ts=4:sts=4:sw=4:et:
