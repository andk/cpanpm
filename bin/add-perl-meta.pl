#!/usr/local/bin/perl

=pod

 $0 --logs=megainstalldir

looks at one dirent that tells us which perl we are talking about

Ask that perl for its config.


=cut


use strict;
use warnings;

use FindBin ();
use Getopt::Long;
use XML::LibXML;
our %Opt;

sub Usage (){
  "Usage: $0 [--logs=logsdirector]";
}

GetOptions(\%Opt, "logs=s"
          ) or die Usage;

my $logdir = $Opt{logs} || "$FindBin::Bin/../logs";
opendir my $dh, $logdir or die "cannot opendir '$logdir': $!";

my $p = XML::LibXML->new;
for my $dirent (sort readdir $dh) {
  next if $dirent =~ /^\./;
  my $abs = "$logdir/$dirent";
  next unless $abs =~ /(?:^|\/)megainstall\.(\d+T\d+)\.d(?:\/|$)/;
  my $time = $1;
  my $xfile = sprintf "%s/%s", $logdir, $dirent;
  next unless $xfile =~ /\.xml$/;
  next unless -e $xfile;
  my $xml = $p->parse_file($xfile);
  my($ok,$seq,$perl,$patchlevel,$branch);
  $ok = $xml->findvalue("/distro/\@ok");
  $seq = $xml->findvalue("/distro/\@seq") || 0;
  $perl = $xml->findvalue("/distro/\@perl");
  $perl .= "/bin/perl";
  unless (-e $perl) {
    die "perl[$perl] n'exists";
  }
  open my $fh, ">", "$logdir/perl-V.txt" or die "Could not open >$logdir/perl-V.txt: $!";
  open my $pfh, "-|", $perl, "-V" or die "cannot fork: $!";
  while (<$pfh>) {
    print $fh $_;
  }
  close $pfh or die "perl died during -V";
  close $fh or die "could not write: $!";
  last;
}
