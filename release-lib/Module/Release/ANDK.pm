use strict;
use warnings;

package Module::Release::ANDK;
use Module::Release;
use base "Module::Release";
our $VERSION = "0.001";

no strict "refs";

for my $method (qw(
build_makefile
check_cvs
clean
cvs_tag
dist
make_cvs_tag
test
)) {
    *$method = sub { return };
}

1;
