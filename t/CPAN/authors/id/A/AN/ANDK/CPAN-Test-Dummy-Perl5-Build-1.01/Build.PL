use strict;
use Module::Build;

my $b = Module::Build->new(
                           module_name  => 'CPAN::Test::Dummy::Perl5::Build',
                           license      => 'perl',
                           dist_version => '1.01',
                           dist_author  => "Andreas Koenig",
);

$b->create_build_script();
