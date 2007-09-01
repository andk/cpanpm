package CPAN::DeferedCode;

use strict;
use vars qw/$VERSION/;

use overload fallback => 1, map { ($_ => 'run') } qw/
    bool "" 0+
/;

$VERSION = sprintf "%.6f", substr(q$Rev$,4)/1000000 + 5.4;

sub run {
    $_[0]->();
}

1;
