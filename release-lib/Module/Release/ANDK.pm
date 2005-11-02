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
  $messages =~ s/^\s+//;
  $messages =~ s/\s+\z//;
  warn "messages[$messages]";
  die if $messages =~ /\s/;
  $self->{local} = $self->{remote} = $messages;
}

1;
