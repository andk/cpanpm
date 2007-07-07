#!/usr/bin/perl -0777 -nl


=pod

Second implementations with a state machine. Much shorter and even
correcter.

=cut


use strict;
use Dumpvalue;
use Encode qw(decode);
use Encode::Detect ();
use File::Path qw(mkpath);
use List::MoreUtils qw(uniq);
use Time::HiRes qw(sleep);
use YAML::Syck;

our($perl_path) = m|(/home\S+/installed-perls/(?:.*?)/p.*?/perl-5.*?@(?:\d+))|;
our $outdir = $ARGV;
$outdir =~ s/.out$/.d/ or die;
mkpath $outdir;
my $perl = "$perl_path/bin/perl";

sub mystore ($$$$){
  my($shortdistro,$log,$ok,$seq) = @_;
  my $outfile = $shortdistro;
  $outfile =~ s!\.(tar.gz|tgz|tar.bz2|tbz|zip)?$!.xml!;
  $outfile =~ s|$|.xml| unless $outfile =~ /\.xml$/;
  $outfile =~ s|/|!|g;
  $outfile =~ s|^|$outdir/|;
  my($time) = $outdir =~ /(\d{8}T\d{4})/;
  open my $fh, ">:utf8", $outfile or die;
  for ($time,$perl_path,$shortdistro,$ok) {
    s!\&!\&amp;!g;
    s!"!&quot;!g;
    s!<!&lt;!g;
    s!>!&gt;!g;
  }
  my $ulog = decode("Detect",$log);
  my $dumper = Dumpvalue->new(unctrl => "unctrl");
  $ulog =~ s/([\x00-\x09\x0b\x0c\x0e-\x1f])/ $dumper->stringify($1,1) /ge;
  print $fh qq{<distro time="$time" perl="$perl_path" distro="$shortdistro" ok="$ok" seq="$seq">};
  print $fh $ulog;
  print $fh "</distro>\n";
  close $fh or die;
  sleep 1/16;
}

# the first part is a duplication of colorterm-to-html.pl which I
# wrote for my Munich talk:
s!\&!\&amp;!g;
sleep 1;
s!"!&quot;!g;
sleep 1;
s!<!&lt;!g;
sleep 1;
s!>!&gt;!g;
sleep 1;
s!\e\[1;3[45](?:;\d+)?m(.*?)\e\[0m!<span style="color: blue">$1</span>!sg;
sleep 1;
s!\e\[1;31(?:;\d+)?m(.*?)\e\[0m!<span style="color: red">$1</span>!sg;
sleep 1;
#s!\n!<br/>\n!g;
s!\r\n!\n!g;
sleep 1;
s!.+\r!!g;
sleep 1;

{
  my @lines = split /\n/, $_;
  my %seq; # $seq{$shortdistro} = [];
  my $d = "";
  my $shortdistro = "";
  my $i = 0;
 LINE: while (defined($_ = shift @lines)) {
    if (m|<span[^<>]+>Running make for ([A-Z]/[A-Z][A-Z]/)([\w-]+/.+)|) {
      $shortdistro = $2;
      $d = "$1$2";
      $seq{$shortdistro} ||= [];
    } elsif (m|[ ]{2}([A-Z][\w-]+[A-Z]/\w+.*)|
             && $lines[0] =~ /[ ]{2}.+install\s+--\s+((?:NOT\s)?OK|NA)/
            ) {
      $shortdistro = "XXX";
      my $ok = $1;
      $i++;
      push @{$seq{$shortdistro}}, $_;
      push @{$seq{$shortdistro}}, shift @lines;
      my $log = join "", map { "$_\n" } @{$seq{$shortdistro}};
      mystore($shortdistro,$log,$ok,$i);
      delete $seq{$shortdistro};
      $d = $shortdistro = "";
      next LINE;
    }
    push @{$seq{$shortdistro}}, $_;
  } # while @lines
  open my $rfh, ">", "$outdir/residuum.yml" or die;
  print $rfh YAML::Syck::Dump(\%seq);
  close $rfh or die;
}

if (-e $perl) {
  open my $fh, ">", "$outdir/perl-V.txt" or die "Could not open >$outdir/perl-V.txt: $!";
  open my $pfh, "-|", $perl, "-V" or die "cannot fork: $!";
  while (<$pfh>) {
    print $fh $_;
  }
  close $pfh or die "perl died during -V";
  close $fh or die "could not write '$outdir/perl-V.txt': $!";
}

__END__
