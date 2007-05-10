#!/usr/local/bin/perl

=pod

 $0 [--logs=logsdir] distro

looks at all dirents in logsdir (which defaults to C<./logs>). If an
entry looks like a megainstall directory it is probed for distro XML
file and if it is there, one line is output.

 $0 --logs=megainstalldir

looks at all dirents in this megainstall directory that end in C<.xml>
and outputs a line for each.

=cut


use strict;
use warnings;

use FindBin ();
use Getopt::Long;
use XML::LibXML;
our %Opt;

sub Usage (){
  "Usage: $0 [--logs=logsdirector] [distro]";
}

GetOptions(\%Opt, "logs=s"
          ) or die Usage;

my $logdir = $Opt{logs} || "$FindBin::Bin/../logs";
opendir my $dh, $logdir or die "cannot opendir '$logdir': $!";

my $distro = shift;
if ($distro) {
  $distro =~ s!\.(tar.gz|tgz|tar.bz2|tbz|zip)?$!.xml!;
  $distro =~ s|$|.xml| unless $distro =~ /\.xml$/;
  $distro =~ s|/|!|g;
}
my $p = XML::LibXML->new;
for my $dirent (sort readdir $dh) {
  next if $dirent =~ /^\./;
  my $abs = "$logdir/$dirent";
  next unless $abs =~ /(?:^|\/)megainstall\.(\d+T\d+)\.d(?:\/|$)/;
  my $time = $1;
  my $xfile = sprintf "%s/%s", $logdir, $dirent;
  $xfile .= "/$distro" if $distro;
  next unless $xfile =~ /\.xml$/;
  next unless -e $xfile;
  my $xml = $p->parse_file($xfile);
  my($ok,$seq,$perl,$patchlevel,$branch);
  $ok = $xml->findvalue("/distro/\@ok");
  $seq = $xml->findvalue("/distro/\@seq") || 0;
  $perl = $xml->findvalue("/distro/\@perl");
  ($branch,$patchlevel) = $perl =~ m|/installed-perls/(.*?)/p.*?/perl-5.*?@(\d+)|;
  printf("%s %-10s %6d %4d %-6s",
         $time,
         $branch,
         $patchlevel,
         $seq,
         $ok,
        );
  if ($distro) {
    print "\n";
  } else {
    print " $dirent\n";
  }
}
