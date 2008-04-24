=head1 NAME

CPAN::PERL5INC - Keep all tested and not installed modules in INC

=head1 SYNOPSIS

  PERL5OPT="-MCPAN::PERL5INC=yaml_module,$y,tempfile,$t";

=head1 DESCRIPTION

CPAN.pm keeps track of tested but not yet installed modules. To make
these modules available to modules that are tested later, it normally
populates the environment variable PERL5LIB.

This module is an alternative to PERL5LIB that circumvents limitations
of the size of the environment. The import routine is abused to let
the caller set a YAML module and a tempfile. The YAML module will then
be used to load the tempfile. The loaded object must be a hash and the
array reference in the C<inc> slot of that hash will be appended to
@INC.

When the number of tested but uninstalled distros grows, CPAN tries to
use this module after the threshold C<threshold_perl5lib_upto> is
reached. It issues a warning when this is not feasible. A YAML module
should be installed and File::Temp should be available in order to get
it working.

=head1 BUGS

Does not work with paths containing comma. Does not work when the
environment variable PERL5OPT is already in use for something else.
Tests that have tainting turned on often fail when PERL5OPT is set
because the variable is then ignored.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>




=cut

use strict;
package CPAN::PERL5INC;
use vars qw($VERSION $yaml_module);
$VERSION = "5.51";
sub import {
    my($class,%args) = @_;
    my $arg_y = $args{yaml_module};
    my $arg_t = $args{tempfile};
    return if !$arg_t && !$arg_y;
    if ($arg_y) {
        my $yinc = $yaml_module = $arg_y;
        $yinc =~ s|::|/|g;
        $yinc .= ".pm";
        require $yinc;
    } else {
        die "missing argument yaml_module";
    }
    if ($arg_t) {
        my $loader = UNIVERSAL::can($yaml_module, "LoadFile");
        my $loaded = $loader->($arg_t);
        # require YAML::Syck; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . YAML::Syck::Dump({inc=>$loaded->{inc}, INC => \@INC}); # XXX
        unshift @INC, map { /^(.+)$/; $1 } @{$loaded->{inc}}; # untaint
    } else {
        die "missing argument tempfile";
    }
}
1;

__END__

