use strict;
use warnings;

package Module::Relase::ANDK;
use Module::Release;
use base "Module::Release";

*build_makefile =
    *test =
    *check_cvs =
    *cvs_tag =
    *make_cvs_tag =
    sub { return }

1;
