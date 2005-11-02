use strict;
use warnings;

package Module::Release::ANDK;
use Module::Release;
use base "Module::Release";
our $VERSION = "0.001";

*build_makefile =
    *test =
    *check_cvs =
    *cvs_tag =
    *make_cvs_tag =
    *clean =
    sub { return };

sub dist {
  my($self) = @_;
  my $messages = $self->run( "$self->{make} what-is-the-release-name 2>&1" );
  my($release_name) = $messages =~ /release-name-is:\s+(.+)/;
  die "bad release name[$release_name]" if $release_name =~ /\s/ or $release_name !~ /\.tar\.gz$/;
  $self->{local} = $self->{remote} = $release_name;
}

1;
