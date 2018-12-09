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

The plugin system in the CPAN shell was introduced in version 2.07 and
is still considered experimental.

=head2 Goal of the TraceDeps plugin

Trying to nail down the various dependecies (configure_requires,
build_requires, and requires) in the various stages () of the build
system.

Implemented as pre-make, post-make, post-test, and post-install hooks,
this plugin writes dependency info into its tracedeps file.

B<WARNING:> plugin is in early dev stage (alpha); it can change
without prior notice between releases.

=head2 OPTIONS

The target directory to store the spec files in can be set using C<dir>
as in

  o conf plugin_list push CPAN::Plugin::TraceDeps=dir,/tmp/tracedeps-000042

The default directory for this is the
C<plugins/CPAN::Plugin::TraceDeps> directory in the I<cpan_home>
directory.

=head1 AUTHOR

Andreas Koenig <andk@cpan.org>

=cut

package CPAN::Plugin::TraceDeps;

our $VERSION = '0.0.1';

use File::Path;
use File::Spec;

sub plugin_requires {
    qw(JSON::XS Log::Log4perl);
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
    $CPAN::META->use_inst($_) for $self->plugin_requires;
    while (my($arg,$val) = splice @rest, 0, 2) {
        $self->$arg($val);
    }
    $self->dir_default(File::Spec->catdir($CPAN::Config->{cpan_home},"plugins",__PACKAGE__));
    $self;
}

for my $sub (qw(
  pre_get
  post_get
  pre_make
  post_make
  pre_test
  post_test
  pre_install
  post_install
)) {
    *$sub = sub {
        my $self = shift;
        my $distribution_object = shift;
        $self->log($sub, $distribution_object);
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
    use Time::Piece;
    my $t = localtime;
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
    $self->logger->info(sprintf "%s=%s:%s\n",
        __PACKAGE__,
        $VERSION,
        $self->encode({
            method => $method,
            (map { $_ => $d->{$_} } qw(prereq_pm CALLED_FOR mandatory reqtype sponsored_mods)),
            (map { $_ => "" . $d->{$_} } grep { defined $d->{$_} } qw(make make_test install)),
            (map { $_ => $d->$_ } qw(pretty_id)),
        }));
}

1;
