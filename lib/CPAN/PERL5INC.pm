=head1 NAME

CPAN::PERL5INC - Keep all tested and not installed modules in INC

=head1 SYNOPSIS

  PERL5OPT="-MCPAN::PERL5INC=yaml_module,$y -MCPAN::PERL5INC=tempfile,$t";

=head1 DESCRIPTION

CPAN.pm keeps track of tested but not yet installed modules. To make
these modules available to modules that are tested later, it normally
populates the environment variable PERL5INC.

This module is an alternative to PERL5LIB that circumvents limitations
of the size of the environment. The import routine is abused to let
the caller set a YAML module and a tempfile. The YAML module will then
be used to load the tempfile. The loaded object must be a hash and the
array reference in the C<inc> slot of that hash will be appended to
@INC.

When the number of tested but uninstalled distros grows, CPAN tries to
use this module. It issues a warning when this is not feasible. A YAML
module should be installed and File::Temp should be available in order
to get it working.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>




=cut

use strict;
package CPAN::PERL5INC;
use vars qw($yaml_module);
sub import {
    my($class,$what,@args) = @_;
    return unless $what;
    if ($what eq "yaml_module") {
        my $yinc = $yaml_module = $args[0];
        $yinc =~ s|::|/|g;
        $yinc .= ".pm";
        require $yinc;
    } if ($what eq "tempfile") {
        my $loader = UNIVERSAL::can($yaml_module, "LoadFile");
        my $loaded = $loader->($args[0]);
        push @INC, @{$loaded->{inc}};
        # require YAML::Syck; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . YAML::Syck::Dump({inc => $inc}); # XXX
    }
}
1;

__END__

