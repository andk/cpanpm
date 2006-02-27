use strict;
use ExtUtils::MakeMaker;
my @sign = (MM->can("signature_target") ? (SIGN => 1) : ());
WriteMakefile(
              NAME          => 'Bundle::CPAN',
              VERSION_FROM  => 'CPAN.pm',
              @sign,
              dist => {
                       DIST_DEFAULT => (
                                        'Makefile all tardist'
                                       ),
                       COMPRESS => 'gzip -9f'
                      },
);

package MY;

sub makefile {
  my $self = shift;
  my $result = $self->SUPER::makefile(@_);
  $result =~ s/ : / :: /;
  $result;
}

sub postamble {
  q{
Makefile :: CPAN.pm
}
}

