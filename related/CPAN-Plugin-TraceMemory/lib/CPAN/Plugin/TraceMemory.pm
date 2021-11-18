=head1 NAME

CPAN::Plugin::TraceMemory - logging memory usage

=head1 SYNOPSIS

  # once in the cpan shell
  o conf plugin_list push CPAN::Plugin::TraceMemory

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

=head2 Purpose

This plugin logs memory usage in the eight stages

  pre_get
  post_get
  pre_make
  post_make
  pre_test
  post_test
  pre_install
  post_install

The name of the logfile is generated using an iso 8601 timestamp, e.g.
20211112T091455.log.

A single dependency log event is written to a single line consisting
of a timestamp, a colon, and a JSON object, e.g. (here broken into three
lines):

  2021-11-16 21:33:53.646381:{"committed":"2262380","method":"pre_get",
  "pretty_id":"INGY/JS-0.29.tar.gz","statm_share":7024,
  "statm_size":621828}

=head2 Graceful degradation

When prerequisites for this plugin are missing, a warning is displayed
and logging is skipped. As soon as all prerequisites are installed,
logging starts.

=head2 OPTIONS

The target directory to store the log file can be set using C<dir>
as in

  o conf plugin_list push CPAN::Plugin::TraceMemory=dir,/tmp/tracedeps-000042

The default directory for this is the
C<plugins/CPAN::Plugin::TraceMemory> directory in the I<cpan_home>
directory.

=head1 AUTHOR

Andreas Koenig <andk@cpan.org>

COPYRIGHT AND LICENSE

Copyright (C) 2021 by Andreas König

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

SEE ALSO

CPAN

=cut

package CPAN::Plugin::TraceMemory;

our $VERSION = '0.0.1';

use File::Path;
use File::Spec;
use Storable ();
use CPAN::Queue;
use Time::HiRes ();
use Sys::Hostname qw(hostname);

sub plugin_requires {
    qw(JSON::XS Log::Dispatch::File Log::Log4perl Log::Log4perl::DateFormat Time::Piece);
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
            sprintf "Plugin TraceMemory is missing %s %s, logging is off\n",
            $prereqfiller,
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
BEGIN { __PACKAGE__->__accessor($_) for qw(dir dir_default) }

sub new {
    my($class, @rest) = @_;
    my $self = bless {}, $class;
    while (my($arg,$val) = splice @rest, 0, 2) {
        $self->$arg($val);
    }
    no warnings 'once';
    $self->dir_default(File::Spec->catdir($CPAN::Config->{cpan_home},"plugins",__PACKAGE__));
    $self;
}

{
    my $format;
    sub timestamp {
        my ($secs, $msecs) = Time::HiRes::gettimeofday();
        $format = Log::Log4perl::DateFormat->new("yyyy-MM-dd HH:mm:ss.SSSSSS") unless defined $format;
        $format->format($secs, $msecs);
    }
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
        return unless $self->all_dependencies_satisfied;
        my $distribution_object = shift;
        my $logobj;
        $logobj->{pretty_id} = $distribution_object->pretty_id;
        open my $fh, "/proc/self/statm";
        my($size, $share) = (split /\s/, scalar <$fh>)[0,2];
        $logobj->{statm_size} = 4*$size;
        $logobj->{statm_share} = 4*$share;
        open $fh, "/proc/meminfo";
        local $/;
        my($committed) = <$fh> =~ /^Committed_AS:\s+(\d+)/m;
        $logobj->{committed} = $committed;
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
    my $dispatch;
    sub logger {
        return $dispatch if defined $dispatch;
        my($self) = @_;
        my $target_dir = $self->dir || $self->dir_default;
        File::Path::mkpath($target_dir);
        $logfile ||= File::Spec->catfile($target_dir, $self->isotime . ".log");
        $dispatch = Log::Dispatch->new( outputs => [[ File => filename => $logfile, min_level => 'debug' ]]);
    }
}

my $cnt = 0;
sub log {
    my($self, $method, $d) = @_;
    no warnings 'uninitialized';
    eval {
        $self->logger->info(sprintf "%s:%s\n",
            $self->timestamp,
            $self->encode({
                $cnt++ ? () : (
                    plugin_pkg => __PACKAGE__,
                    plugin_ver => $VERSION,
                    hostname => hostname,
                    perl => $^X,
                    pid => $$,
                ),
                method => $method,
                %$d,
            }));
    };
    $@ and $CPAN::Frontend->mywarn(
            sprintf "Plugin TraceMemory had problems logging, please investigate: %s\n",
                $@
        );
}

1;
