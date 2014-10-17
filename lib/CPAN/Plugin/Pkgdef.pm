
package CPAN::Plugin::Pkgdef;
use base 'CPAN::Plugin';

use strict;
use warnings;

use File::Spec;

our $VERSION = '1.0.0';

######################################################################
sub get_pkg_summary {                    # ;
    my ($self) = @_;

    my %contains = map {($_ => undef)} $self->distribution->containsmods;
    CPAN::Shell->_guess_manpage (
        $self->distribution,
        \%contains,
        $self->distribution_info->dist
    );
}

######################################################################
sub get_pkg_name {                       # ;
    my ($self) = @_;

    $self->distribution_info->dist;
}

######################################################################
sub get_pkg_version {                    # ;
    my ($self) = @_;

    $self->distribution_info->version;
}

######################################################################
sub get_pkg_license {                    # ;
    'unknown'
}

######################################################################
sub get_pkg_url {                        # ;
    'unknown'
}

######################################################################
sub get_pkg_source_url {                 # ;
    my ($self) = @_;

    my $distribution = $self->distribution_object->id;

    # TODO: use prefered mirror instead ?
    "http://search.cpan.org/CPAN/authors/id/" . $distribution;
}

######################################################################
sub get_pkg_description {                # ;
}

######################################################################
sub get_pkg_provides {                   # ;
    my ($self) = @_;

    local $_;
    map {
        my $m = CPAN::Shell->expand ("Module", $_);
        my $v = $m->cpan_version;

        [ $_ => $v ]
    } sort $self->distribution->containsmods;
}

######################################################################
sub get_pkg_requires {                   # ;
    my ($self) = @_;

    local $_;

    # TODO: idea: skip ^Test: unless current is also ^Test:
    # TODO: idea: skip ^ExtUtils: unless current is also ^ExtUtils:

    grep $_->[0] !~ /^(Module::Build)$/, $self->get_pkg_build_requires;
}

######################################################################
sub get_pkg_build_requires {             # ;
    my ($self) = @_;

    my @retval;
    if (my $prereq_pm = $self->distribution->{prereq_pm}) {
        my %req;
        for my $reqkey (keys %$prereq_pm) {
            while (my($k,$v) = each %{$prereq_pm->{$reqkey}}) {
                $req{$k} = $v;
            }
        }
        $req{"Module::Build"} = 0
          if -e File::Spec->catfile ($self->build_dir, "Build.PL" && ! exists $req{"Module::Build"});

        for my $k (sort keys %req) {
            next if $k eq "perl";
            next if $k eq $self->{perl};
            my $v = $req{$k};
            push @retval, [ $k => $v ];
        }
    }

    @retval;
}

######################################################################
sub get_pkg_suggests {                   # ;
}

######################################################################

package CPAN::Plugin::Pkgdef;

1;

__END__

=pod

=head1 NAME

CPAN::Plugin::Pkgdef - Base class for package definition generator plugins

=head1 DESCRIPTION

=head1 METHODS

=head2 get_summary

Returns short summary tag.
Usually it's second part of NAME.

=head2 get_provides

=head2 get_requires

=head2 get_build_requires

=head2 get_suggets

Return list of packages and versions (as arrayref)

