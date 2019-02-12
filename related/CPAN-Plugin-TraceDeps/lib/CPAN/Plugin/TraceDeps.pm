=head1 NAME

CPAN::Plugin::TraceDeps - logging dependecy relations between modules

=head1 SYNOPSIS

  # once in the cpan shell
  o conf plugin_list push CPAN::Plugin::TraceDeps

  # make permanent
  o conf commit

  # disable
  # if it is the last in plugin_list:
  o conf plugin_list pop
  # otherwise, determine the index to splice:
  o conf plugin_list
  # and then use splice, e.g. to splice position 3:
  o conf plugin_list splice 3 1

=head1 DESCRIPTION

=head2 Alpha Status

The plugin system in the CPAN shell was introduced in version 2.07.
This plugin is not yet settled and subject to change without prior
notice.

=head2 Goal of the TraceDeps plugin

Trying to nail down the various dependencies (configure_requires,
build_requires, and requires) in the various stages () of the build
system.

This plugin writes dependency info into its tracedeps file.

=head2 Graceful degradation

When prerequisites for this plugin are missing, a warning is displayed
and logging is skipped. As soon as all prerequisites are installed,
logging starts.

=head2 OPTIONS

The target directory to store the spec files can be set using C<dir>
as in

  o conf plugin_list push CPAN::Plugin::TraceDeps=dir,/tmp/tracedeps-000042

The default directory for this is the
C<plugins/CPAN::Plugin::TraceDeps> directory in the I<cpan_home>
directory.

=head1 AUTHOR

Andreas Koenig <andk@cpan.org>

COPYRIGHT AND LICENSE

Copyright (C) 2019 by Andreas König

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

SEE ALSO

CPAN

=cut

package CPAN::Plugin::TraceDeps;

our $VERSION = '0.0.1';

use File::Path;
use File::Spec;
use Storable ();
use CPAN::Queue;

sub plugin_requires {
    qw(JSON::XS Log::Dispatch::File Log::Log4perl Time::Piece);
}

sub all_dependencies_satisfied {
    my ($self) = @_;
    my @missing;
    for my $prereq ($self->plugin_requires) {
        push @missing, $prereq unless $CPAN::META->has_inst($prereq);
    }
    if (@missing) {
        my $prereqfiller = "prerequisite" . (@missing>1 ? "s" : "");
        $CPAN::Frontend->mywarn(
            sprintf "Plugin TraceDeps is missing $prereqfiller %s, logging is off\n",
                join(", ", @missing)
        );
        return;
    }
    return 1;
}

sub __accessor {
    my ($class, $key) = @_;
    no strict 'refs';
    *{$class . '::' . $key} = sub {
        my $self = shift;
        if (@_) {
            $self->{$key} = shift;
        }
        return $self->{$key};
    };
}
BEGIN { __PACKAGE__->__accessor($_) for qw(dir dir_default log4perlconfig) }

sub new {
    my($class, @rest) = @_;
    my $self = bless {}, $class;
    while (my($arg,$val) = splice @rest, 0, 2) {
        $self->$arg($val);
    }
    $self->dir_default(File::Spec->catdir($CPAN::Config->{cpan_home},"plugins",__PACKAGE__));
    $self;
}

# I suspect we will never use those 7 so they will be removed before
# first public version
for my $sub (qw(
  pre_get
  post_get
  pre_make
  post_make
  pre_test
  post_test
  pre_install
)) {
    *$sub = sub {
        my $self = shift;
        return unless $self->all_dependencies_satisfied;
        my $distribution_object = shift;
        $self->log($sub, $distribution_object);
    };
}

for my $sub (qw(
  post_install
)) {
    *$sub = sub {
        my $self = shift;
        return unless $self->all_dependencies_satisfied;
        my $distribution_object = shift;
        my $logobj = Storable::dclone($distribution_object);
        if (my $called_for = $distribution_object->{CALLED_FOR}) {
            if ($called_for =~ m{/}) {
                # no plan yet what to do with distros
            } elsif (my $nmo = $CPAN::META->instance("CPAN::Module",$called_for)) {
                if (my $inst_file = $nmo->inst_file) {
                    $logobj->{tracedeps_inst_file} = $inst_file;
                }
                if (my $inst_version = $nmo->inst_version) {
                    $logobj->{tracedeps_inst_version} = $inst_version;
                }
                if (my $cpan_version = $nmo->cpan_version) {
                    $logobj->{tracedeps_cpan_version} = $cpan_version;
                }
                my $ancestor = $nmo;
                my @viabundle;
                while (my $viabundle = $ancestor->{viabundle}) {
                    push @viabundle, $viabundle;
                    $ancestor = CPAN::Shell->expandany($viabundle->{id}) or last;
                }
                if (@viabundle) {
                    $logobj->{tracedeps_viabundle} = \@viabundle;
                }
            }
        }
        $self->log($sub, $logobj);
    };
}

{
    my $coder;
    sub encoder {
        my($self) = @_;
        $coder ||= JSON::XS->new->ascii->canonical;
    }
}

sub encode {
    my($self, $hash) = @_;
    $self->encoder->encode($hash);
}

sub isotime {
    my $t = Time::Piece::localtime();
    $t->time_separator("");
    $t->date_separator("");
    $t->datetime;
}

{
    my $logfile;
    sub logger {
        my($self) = @_;
        my $target_dir = $self->dir || $self->dir_default;
        File::Path::mkpath($target_dir);
        $logfile ||= File::Spec->catfile($target_dir, $self->isotime . ".log");
        Log::Log4perl::init_once(\<<HERE);
log4perl.logger = INFO, File
log4perl.appender.File = Log::Dispatch::File
log4perl.appender.File.layout   = PatternLayout
log4perl.appender.File.filename = $logfile
log4perl.appender.File.layout.ConversionPattern = %d{yyyy-MM-dd HH:mm:ss.SSSSSS} %m%n
HERE
        return Log::Log4perl->get_logger();
    }
}

sub log {
    my($self, $method, $d) = @_;
    no warnings 'uninitialized';
    eval {
        $self->logger->info(sprintf "%s=%s:%s\n",
            __PACKAGE__,
            $VERSION,
            $self->encode({
                method => $method,
                (map { $_ => $d->{$_} } qw(
                    CALLED_FOR
                    mandatory
                    prereq_pm
                    reqtype
                    sponsored_mods
                )),
                (map { $_ => "" . $d->{$_} } grep { defined $d->{$_} } qw(
                    coming_from
                    install
                    make
                    make_test
                    signature_verify
                    tracedeps_cpan_version
                    tracedeps_inst_file
                    tracedeps_inst_version
                    unwrapped
                    writemakefile
                )),
                (map { $_ => $d->$_ } qw(pretty_id)),
                (map { $_ => $d->{$_} } grep { exists $d->{$_} } qw(tracedeps_viabundle)),
                (map { ("queue_".$_) => CPAN::Queue->$_() } qw(size)),
            }));
    } or $CPAN::Frontend->mywarn(
            sprintf "Plugin TraceDeps had problems logging, please investigate: %s\n",
                $@
        );
}

1;
