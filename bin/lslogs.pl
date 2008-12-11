#!/usr/local/bin/perl


use FindBin ();

my $logdir = "$FindBin::Bin/../logs";
opendir my $dh, $logdir or die "Could not open '$logfir': $!";
my @LS;
for my $dirent (sort { $b cmp $a } readdir $dh) {
  next unless $dirent =~ /^megainstall\.(\d+T\d+)\.out$/;
  my $time = $1;
  open my $fh, "<", "$logdir/$dirent" or die;
  while (<$fh>) {
    next unless m|^Installing .*?/installed-perls/(.*?)/p.*?/perl-5.*?@(\d+)|;
    push @LS, [$time, $1, $2];
    last;
  }
  last if @LS >= 23;
}
for my $ls (@LS) {
  printf "%s %-10s %6d\n", @$ls;
}
