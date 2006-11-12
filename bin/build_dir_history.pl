=pod

Script to give an overview about the contents of the build_dir/

Status: highly experimental, not intended to be ever brought into production

Todo: select data, filter on data

=cut

use strict;
use warnings;

use lib "lib";
use CPAN 1.8861;
use File::Basename;

CPAN::HandleConfig->load();
my $bd = $CPAN::Config->{build_dir};
opendir my $dh, $bd or die "Could not opendir $bd\: $!";
my @history;
for my $dirent (readdir $dh) {
  next unless $dirent =~ /\.yml$/;
  my $yaml = CPAN->_yaml_loadfile("$bd/$dirent")->[0]; # XXX note: uses internal function
  my(undef, undef, $author) = split m|/|, $yaml->{distribution}{ID};
  push @history, [$yaml->{time},
                  $author,
                  File::Basename::basename($yaml->{distribution}{build_dir}),
                 ];
}
for my $t (sort { $a->[0] <=> $b->[0] } @history) {
  printf "%s %-9s %s\n", scalar localtime $t->[0], $t->[1], $t->[2];
}
