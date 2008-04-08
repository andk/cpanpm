use strict;

use Test::More;
use Config;
use CPAN::Distroprefs;

eval "require YAML; 1" or plan skip_all => "YAML required";
plan tests => 2;

my $finder = CPAN::Distroprefs->find(
  './distroprefs',
  {
    yml => 'YAML',
    dd  => 'Data::Dumper',
    st  => 'Storable',
  },
);

isa_ok($finder, 'CPAN::Distroprefs::Iterator');

my %arg = (
  env => \%ENV,
  perl => $^X,
  perlconfig => \%Config::Config,
  module => [],
  distribution => 'HDP/Perl-Version-1',
);

my $found;
while (my $result = $finder->next) {
  next unless $result->is_success;
  for my $pref (@{ $result->prefs }) {
    if ($pref->matches(\%arg)) {
      $found = {
        prefs => $pref->data,
        prefs_file => $result->abs,
      };
    }
  }
}
is_deeply(
  $found,
  {
    prefs => YAML::LoadFile('distroprefs/HDP.Perl-Version.yml'),
    prefs_file => 'distroprefs/HDP.Perl-Version.yml',
  },
  "found matching prefs",
);
