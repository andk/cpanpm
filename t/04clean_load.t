# check if all the modules can load stand-alone

use strict;
eval 'use warnings';

my @modules;
use File::Find;
find(\&list_modules, 'blib/lib');

use Test::More;
plan(tests => scalar @modules);
foreach my $file (@modules) {
    #diag $file;
    system("$^X -c $file >our 2>err");
    my $fail;
    if (open ERR, '<err') {
        my $stderr = join('', <ERR>);
        if ($stderr !~ /^$file syntax OK$/) {
            $fail = $stderr;
        }
    } else {
        $fail = "Could not open 'err' file after running $file";
    }
    ok(!$fail, "Loading $file") or diag $fail;
}


sub list_modules {
    return if $_ !~ /\.pm$/;
    push @modules, $File::Find::name;
    return;
}
