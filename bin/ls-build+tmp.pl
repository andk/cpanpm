

=head1 

read the build directories and the /tmp and the home directory and
merge them in such a way that we can say which distro dropped
something.

=cut

use strict;
use warnings;


use Getopt::Long;
use Time::HiRes qw(sleep);

my %ignore = map { ;"/tmp/$_" => 1; } ".X121-lock", ".UUID_NODEID";
for my $de (qw(.aptitude backup .bash_history .bash_logout .bash_profile .bashrc bin .ccache .cpan .cpanplus .cpanreporter .crossfire )) {
    $ignore{"/home/sand/$de"} = 1;
}
my %Config = (
              cleanup => 30, # only for /tmp
             );

GetOptions(\my %config,
           (map { "$_=s" } keys %Config),
           "debug!",
          ) or die;


while (my($k,$v) = each %config) {
  $Config{$k} = $v;
}


my @all;
for my $dir (qw(/tmp /home/sand/.cpan/build /home/k/.cpan/build)) {
  opendir my $dh, $dir or die "Couldn't opendir: $!";
  push @all, map { "$dir/$_" } readdir $dh;
}
@all = grep { ! exists $ignore{$_} } @all;
my @rall = sort { $a->[1] <=> $b->[1] }
    map { [$_, (stat$_)[9]] } @all;
DIRENT: for my $dirent (@rall) {
  if (my $cleanup_time = $Config{cleanup}) {
    if ($dirent->[0] =~ m|^/tmp/........|) {
      my $age = sprintf "%.4f", -M $dirent->[0];
      if ($age > $cleanup_time) {
        require File::Path;
        warn "Going to rmtree '$dirent->[0]' age[$age]\n";
        sleep 0.05;
        File::Path::rmtree($dirent->[0]);
        next DIRENT;
      }
    }
  }
  if ($Config{debug}) {
    my @t = localtime($dirent->[1]);
    $t[5]+=1900;
    $t[4]++;
    my $sigil = -d $dirent->[0] ? "/" : "";
    printf "%04d-%02d-%02dT%02d:%02d:%02d %6d %s%s\n", @t[5,4,3,2,1,0], -s $dirent->[0], $dirent->[0], $sigil;
    # printf "%s\n", $dirent->[0];
  }
}
