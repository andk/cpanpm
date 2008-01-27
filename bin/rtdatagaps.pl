
# $HeadURL: /local/cpanpm/trunk/bin/query-rt-group-by-requestor.pl $


=head1 rtdataholes

Read YAML databases and list all missing tickets in the style needed
as datainput for the rt-deleter.pl

=cut

use strict;
use warnings;

use Getopt::Long;
use Set::Integer::Gapfillers;
use Set::IntSpan::Fast;
use YAML::Syck;
$YAML::Syck::ImplicitUnicode = 1;

my $yaml_db_file = __FILE__;
$yaml_db_file =~ s|[^/]+\.pl$|query-rt-group-by-requestor.yml|;
my $Q;
if (-e $yaml_db_file) {
  print "Reading '$yaml_db_file'\n";
  $Q = YAML::Syck::LoadFile($yaml_db_file);
} else {
  die "Didn't find '$yaml_db_file'";
}

my $D;
$yaml_db_file =~ s|[^/]+\.yml$|rt-deleter.yml|;
if (-e $yaml_db_file) {
  print "Reading '$yaml_db_file'\n";
  $D = YAML::Syck::LoadFile($yaml_db_file);
} else {
  die "Didn't find '$yaml_db_file'";
}

print "Constructing the set\n";
my $set = Set::IntSpan::Fast->new();
for my $k (keys %{$Q->{tickets}}) {
  $set->add($k) if keys %{$Q->{tickets}{$k}};
}
for my $k (keys %$D) {
  $set->add($k);
}

my $fset = $set->as_string;
print "$fset\n";

print "Constructing the gapfiller\n";
my @have = map { if (/-/) {
  [ split /-/, $_ ]
} else {
  [ $_, $_ ]
} } split /,/, $fset;

my $sigf = Set::Integer::Gapfillers->new(
                                         lower => 1,
                                         upper => $have[-1][1],
                                         sets  => \@have,
                                        );
my $gf = $sigf->gapfillers;
for my $i (0..$#$gf) {
  my $gap = $gf->[$i];
  if ($gap->[0]==$gap->[1]) {
    print " $gap->[0]";
  } else {
    print " $gap->[0]..$gap->[1]";
  }
}
print "\n";
