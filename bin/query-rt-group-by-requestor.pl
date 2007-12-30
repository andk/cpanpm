use strict;
use warnings;

use RT::Client::REST;
use Getopt::Long;
use List::Util qw(max);
use YAML::Syck;

my %Config = (
              server      => 'http://rt.cpan.org',
              username    => 'ANDK',
              password    => '',
              chunksize   => 400,
             );

GetOptions(\my %config, map { "$_=s" } keys %Config);
while (my($k,$v) = each %config) {
  $Config{$k} = $v;
}

my $yaml_db_file = __FILE__;
$yaml_db_file =~ s/\.pl$/.yml/;
my $ALL;
if (-e $yaml_db_file) {
  $ALL = YAML::Syck::LoadFile($yaml_db_file);
} else {
  $ALL = {};
}
my $curmax = max keys %{$ALL->{tickets} || {}};
$curmax ||= 1;
FINDHOLES: for (my $i = 1; $i <= $curmax; $i++) {
  if (exists $ALL->{tickets}{$i}) {
  } else {
    $curmax = $i;
    last FINDHOLES;
  }
}

my $nextmax = $curmax + $Config{chunksize};

my $rt = RT::Client::REST->new(
                               server  => $Config{server},
                               timeout => 300
                              );

if ($Config{password}) {
  eval { $rt->login( username => $Config{username}, password => $Config{password} ); };
  die "problem logging in: '$@'" if $@;

  my @ids;
  eval {
    @ids = $rt->search(
                       type    => 'ticket',
                       query   => qq[
            (Id >= $curmax and Id <= $nextmax)
        ],
                      );
  };
  die "search failed: $@" if $@;

  my %ids;
  @ids{@ids} = ();
  $|=1;
  print "filling $curmax..$nextmax\n";
 ID: for my $id ($curmax..$nextmax) {
    if ($ALL->{tickets}{$id}){
    } else {
      my $feedback;
      if (exists $ids{$id}) {
        $feedback = ".";
      } elsif (keys %ids) {
        $feedback = "_";
      } else {
        print "stopping at $id. Maybe we have reached the upper end\n";
        last ID;
      }
      $ALL->{tickets}{$id} = exists $ids{$id} ? $rt->show(type => 'ticket', id => $id) : {};
      print $feedback;
    }
    delete $ids{$id};
    unless ($id % 15){
      print "z";
      sleep 3;
    }
  }
  YAML::Syck::DumpFile("$yaml_db_file.new", $ALL);
  rename "$yaml_db_file.new", $yaml_db_file;
  print "filled\n";
}

sub who {
  my($v) = @_;
  my $who = $v->{Requestors} || $v->{Creator};
  return "" unless $who;
  if ($who =~ s/\@cpan\.org$//) {
    $who = uc $who;
  }
  my %alias = (
               'schwern@pobox.com' => 'MSCHWERN',
               'slaven@rezic.de'   => 'SREZIC',
               'cpan@ali.as'       => 'ADAMK',
              );
  $who = $alias{$who} || $who;
}

keys %{$ALL->{tickets}}; # reset iterator
my %S;
TICKET: while (my($k,$v) = each %{$ALL->{tickets}}) {
  my $who = who($v);
  next TICKET unless $who;
  $S{$who}++;
}
my $top = 1;
for my $k (sort {$S{$b} <=> $S{$a}} keys %S) {
  printf "%2d: %34s %4d\n", $top, $k, $S{$k};
  last if $top >= 15;
  $top++;
}
