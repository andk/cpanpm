package CPAN::ToDist::Deb::Template;

use strict;
use warnings;
use base qw/CPAN::ToDist::Template/;

sub get_control {
    return <<'EOC';
Package: [% package %]
Version: [% version %]
Architecture: [% architecture %]
Maintainer: [% maintainer %]
Installed-Size: [% installed_size %]
Depends: [% depends %]
Suggests: [% suggests %]
Section: [% section %]
Priority: [% priority %]
Homepage: [% homepage %]
Description: [% descr %]
[% long_descr %]
EOC
}

1;
