package CPAN::ToDist::Template;

use strict;
use warnings;
use Carp;
use Template;
use base qw/Class::Accessor::Fast/;

sub process {
    my ($self, $template, $args) = @_;

    my $tt = Template->new;
    my $output;

    $tt->process(
            \$self->get_input($template),
            $args,
            \$output,
    ) or die $tt->error;

    return $output;
}

sub get_input {
    my ($self, $template) = @_;

    my $meth = "get_$template";
    return $self->$meth;
}

1;
