use strict;
use warnings;

package Module::Release::ANDK;
use Module::Release;
use base "Module::Release";
our $VERSION = "0.001";

*build_makefile =
    *test =
    *check_cvs =
    *cvs_tag =
    *make_cvs_tag =
    *clean =
    sub { return };

1;
