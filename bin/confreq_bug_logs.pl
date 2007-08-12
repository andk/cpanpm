#!/usr/bin/perl

#!/home/src/perl/repoperls/installed-perls/perl/ppP8264/perl-5.8.0@31653/bin/perl


use Tie::IxHash;
use CPAN::DistnameInfo;
my $t = tie %S, "Tie::IxHash" or die "cannot tie: $!";
ARGV: for my $argv (glob "logs/megainstall.20070{727T0705,730T1247,803T0330,810T2248,812T0825,812T1010}.out") {
  open my $fh, $argv or die;
 LINE: while (<$fh>) {
    # next unless /XML-RSS/;
    if (my($d) = /Running make for ([\040-\177]+)/){
      if ($d =~ /XML-RSS-\d/) {
        warn "...$argv\n  $d\n";
      }
      next LINE if $seen{$argv,$d}++;
      my $dinidi = CPAN::DistnameInfo->new($d)->dist;
      $S{$dinidi}++;
      if ($d =~ /XML-RSS/) {
        warn "...$argv\n   $d\n      $dinidi\n      $S{$dinidi}\n";
      }
    }
  }
}
# print map { "$_\n" } grep { $S{$_}==6 } keys %S;
# dont know why the above thing doesnt work
# I verified with 5.8.7 and bleadperl@31653
# also not works (keys %S) instead of $t->Keys; no idea whats going on
for ($t->Keys) {
# for (keys %S) {
  next unless $S{$_} == 6;
  print "$_\n";
}
