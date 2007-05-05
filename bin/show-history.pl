#!/usr/local/bin/perl


use strict;
use warnings;

use FindBin ();
use Getopt::Long;
use XML::LibXML;
our %Opt;

sub Usage (){
  "Usage: $0 [--logs=logsdirector] distro";
}

GetOptions(\%Opt, "logs=s"
          ) or die Usage;

my $logdir = $Opt{logs} || "$FindBin::Bin/../logs";
opendir my $dh, $logdir or die "cannot opendir '$logdir': $!";

my $distro = shift or die Usage;
$distro =~ s!\.(tar.gz|tgz|tar.bz2|tbz|zip)?$!.xml!;
$distro =~ s|$|.xml| unless $distro =~ /\.xml$/;
$distro =~ s|/|!|g;
my $p = XML::LibXML->new;
for my $dirent (sort readdir $dh) {
  next unless $dirent =~ /^megainstall\.(\d+T\d+)\.d$/;
  my $time = $1;
  my $xfile = sprintf "%s/%s/%s", $logdir, $dirent, $distro;
  next unless -e $xfile;
  my $xml = $p->parse_file($xfile);
  my($ok,$seq,$perl,$patchlevel,$branch);
  $ok = $xml->findvalue("/distro/\@ok");
  $seq = $xml->findvalue("/distro/\@seq") || 0;
  $perl = $xml->findvalue("/distro/\@perl");
  ($branch,$patchlevel) = $perl =~ m|/installed-perls/(.*?)/p.*?/perl-5.*?@(\d+)|;
  printf("%s %-12s %6d %4d %s\n",
         $time,
         $branch,
         $patchlevel,
         $seq,
         $ok,
        );
}
