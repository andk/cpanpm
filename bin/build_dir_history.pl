=pod

Script to give an overview about the contents of the build_dir/

Todo: select data, filter on data

=cut

use strict;
use warnings;

use CPAN;
use CPAN::HandleConfig;
CPAN::HandleConfig::require_myconfig_or_config();
use YAML::Syck;

my $bd = $CPAN::Config->{build_dir};
opendir my $dh, $bd or die "Could not opendir $bd\: $!";
my @history;
for my $dirent (readdir $dh) {
  next unless $dirent =~ /\.yml$/;
  my $yaml = YAML::Syck::LoadFile("$bd/$dirent");
  push @history, [$yaml->{time}, $yaml->{distribution}{ID}];
}
for my $t (sort { $a->[0] <=> $b->[0] } @history) {
  printf "%s %s\n", scalar localtime $t->[0], substr $t->[1], 5;
}
