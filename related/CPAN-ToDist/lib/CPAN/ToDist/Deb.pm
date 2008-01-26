package CPAN::ToDist::Deb;

use strict;
use warnings;
use IO::File;
use List::Util qw/first/;
use File::Temp qw/tempdir/;
use File::Spec::Functions qw/catdir catfile/;
use base qw/CPAN::ToDist/;

__PACKAGE__->mk_accessors(qw/
        build_dir
        deb_dir
        package_prefix
        package_suffix
/);

sub new {
    my ($class, $args) = @_;

    my $self = $class->SUPER::new({
        package_prefix => 'cpan-',  # cpan- instead of lib to not clash with official packages
        package_suffix  => '-perl',
        %{ $args },
    });

    $self->build_dir( tempdir() )
        unless defined $self->build_dir;

    $self->deb_dir( catdir($self->build_dir, 'DEBIAN') )
        unless defined $self->deb_dir;

    return $self;
}

sub prepare {
    my ($self) = @_;

    $self->SUPER::prepare;

    my $old_umask = umask 0;
    $self->mkpath($self->deb_dir, 0755);
    umask $old_umask;

    return;
}

sub gen_control {
    my ($self) = @_;

    my $fh = IO::File->new( catfile($self->deb_dir, 'control'), 'w+' )
        or die $!;

    my $content  = $self->template->process('control', {
            map { my $meth = "subst_$_"; ($_ => $self->$meth) }
            qw/package version    architecture maintainer installed_size
               depends suggests   section      priority   homepage
               descr   long_descr/,
    });

    $fh->print($content);
    $fh->close;

    return;
}

sub build {
    my $self = shift;

    local $CPAN::Config->{makepl_arg} = 'INSTALLDIRS=site';
    local $CPAN::Config->{mbuild_arg} = 'installdirs=site';

    return $self->SUPER::build(@_);
}

sub fake_install {
    my ($self) = @_;

    $self->distribution->test;
}

sub generate {
    my ($self) = @_;

    $self->fake_install;
    $self->gen_control;
    $self->gen_deb;

    return;
}

sub fixup_distname {
    my ($self, $name) = @_;

    # remove invalid chars
    $name =~ tr/_/-/;

    $name = lc $name;

    return $name;
}

sub subst_package {
    my ($self) = @_;

    my $ret = '';

    $ret .= $self->package_prefix;
    $ret .= $self->fixup_distname( $self->distinfo->dist );
    $ret .= $self->package_suffix;

    return $ret;
}

sub subst_version {
    my ($self) = @_;

    my $dist = $self->distinfo->version;

    #FIXME: not all cpan version numbers are good debian version numbers?

    $dist .= '-cpan1';

    return $dist;
}

sub subst_architecture {
    my ($self) = @_;

    my $contains_xs = first {
        CPAN::Shell->expand("Module", $_)->xs_file
    } $self->distribution->containsmods;

    if ($contains_xs) {
        #FIXME
        chomp (my $arch = `dpkg-architecture -qDEB_HOST_ARCH`);
        return $arch;
    }

    return 'all';
}

sub subst_maintainer {
    my ($self) = @_;

    # TODO: use pwent, environment, config, etc.
    return 'Unknown';
}

sub subst_installed_size {
    my ($self) = @_;

    my $dir = $self->build_dir;
    chomp (my $du_ouput = `du --exclude=DEBIAN $dir`);

    my ($size) = $du_ouput =~ /(\d+)/;

    return $size;
}

sub subst_depends {
    my ($self) = @_;

    return ''; #FIXME
}

sub subst_suggests {
    my ($self) = @_;

    return ''; #FIXME
}

sub subst_section {
    return 'perl';
}

sub subst_priority {
    return 'extra';
}

sub subst_homepage {
    my ($self) = @_;

    return 'http://search.cpan.org/dist/'. $self->distinfo->dist;
}

sub subst_descr {
    my ($self) = @_;

    return ''; #FIXME
}

sub subst_long_descr {
    my ($self) = @_;

    return ''; #FIXME
}

sub gen_deb {
    my ($self) = @_;

    system(qw/dpkg-deb --build/, $self->build_dir, catfile($self->destination, 'bar.deb'));
}

1;
