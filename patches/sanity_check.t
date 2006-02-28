#!/usr/bin/perl -w
use strict;
use Test::More tests => 5;
use Data::Dumper;

use_ok "CPAN::HandleConfig";

{
    local $CPAN::Config = {};
    is_deeply( { CPAN::HandleConfig->sanity_check() }, {}, "Sanity check for undefined 'make' entry works" )
        or diag Dumper { CPAN::HandleConfig->sanity_check() };
};

{
    local $CPAN::Config = {
        make => '/some/path with whitespace/in it/where the file doesnt/exist',
    };
    is_deeply( { CPAN::HandleConfig->sanity_check() }->{make},
        [
                       'A path seems to be given in >/some/path with whitespace/in it/where the file doesnt/exist< but the file was not found.',
                       '>/some/path with whitespace/in it/where the file doesnt/exist<
seems to contain whitespace but is not quoted.
This might be OK if there are additional commands you
want to pass to your make utility. If you want to use
"/some/path with whitespace/in it/where the file doesnt/exist"
as your make program, please add appropriate quotes
to the line in Config.pm.
',
        ], "Sanity check for unquoted 'make' entry works" )
        or diag Dumper { CPAN::HandleConfig->sanity_check() };
};

{
    local $CPAN::Config = {
        make => 'make',
    };
    is_deeply( { CPAN::HandleConfig->sanity_check() }, {}, "Sanity check for bare 'make' is silent" )
        or diag Dumper { CPAN::HandleConfig->sanity_check() };
};

{
    local $CPAN::Config = {
        make => 'nmake.exe',
    };
    is_deeply( { CPAN::HandleConfig->sanity_check() }, {}, "Sanity check for bare 'make' is silent (Win32 variant)" );
};

