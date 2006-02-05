use strict;
use Module::Build;

Module::Build->new(
                   module_name         => 'CPAN::Test::Dummy::Perl5::Build',
                   dist_version        => '1.01',
)->create_build_script;
