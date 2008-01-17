package CPAN::ToDist;

use strict;
use warnings;
use Carp;
use CPAN;
use File::Path ();
use CPAN::DistnameInfo;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/
        distribution
        distinfo
        destination
/);

our $VERSION = '0.01';

sub new {
    my ($class, $args) = @_;

    my $self = $class->SUPER::new({
            distribution =>
                (defined $args->{module}
                    ? $CPAN::META->instance('CPAN::Distribution', $args->{module}->cpan_file)
                    : $args->{distribution}),
            %{ $args },
    });

    $self->distinfo( CPAN::DistnameInfo->new($self->distribution->id) );

    return $self;
}

sub run {
    my ($self) = @_;

    $self->prepare;
    $self->build;
    $self->generate;

    return;
}

sub mkpath {
    my ($self, $paths, $mode) = @_;

    $paths = [$paths]
        unless ref $paths eq 'ARRAY';

    $mode ||= 777;

    #TODO: handle errors
    File::Path::mkpath($paths, 0, $mode);

    return;
}

sub prepare {
    my ($self) = @_;

    $self->mkpath($self->destination);
}

sub build {
    my ($self) = @_;

    $self->distribution->make;

    return;
}

sub template_class {
    my ($self) = @_;

    my $class = ref $self;
    $class .= '::Template';

    return $class;
}

sub ensure_class_loaded {
    my ($self, $class) = @_;

    #FIXME
    eval "require $class;";
    die $@ if $@;
}

sub template {
    my $self = shift;

    my $template_class = $self->template_class;
    $self->ensure_class_loaded($template_class);

    return $template_class->new(@_);
}

sub generate {
    croak 'abstract';
}

1;
