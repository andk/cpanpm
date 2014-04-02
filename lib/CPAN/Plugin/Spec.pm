package CPAN::Plugin::Spec;

use Class::Singleton; # to be revised
use base "Class::Singleton"; # to be revised

sub post_test {
    warn "HERE";
    sleep 12;
}

1;
