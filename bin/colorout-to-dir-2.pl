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
use Time::HiRes qw(sleep time);
use YAML::Syck;

our $start = time;
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

sub measure ($) {
  warn sprintf "[%s]time since last measure[%.4f]\n", shift, time - $start;
  sleep 1;
  $start = time;
}

# the first part is a duplication of colorterm-to-html.pl which I
# wrote for my Munich talk:

s!\&!\&amp;!g;
measure("amp");
s!"!&quot;!g;
measure("quot");
s!<!&lt;!g;
measure("lt");
s!>!&gt;!g;
measure("gt");
s!\e\[1;3[45](?:;\d+)?m(.*?)\e\[0m!<span style="color: blue">$1</span>!sg;
measure("blue");
s!\e\[1;31(?:;\d+)?m(.*?)\e\[0m!<span style="color: red">$1</span>!sg;
measure("red");
#s!\n!<br/>\n!g;
s!\r\n!\n!g;
measure("CRLF");

{
  my @lines = split /\n/, $_;
  measure("split");
  my %seq; # $seq{$shortdistro} = [];
  my @longdistro;
  my @shortdistro;
  my $i = 0;
 LINE: while (defined($_ = shift @lines)) {
    s!.+?\r!!g;
    if (m|<span[^<>]+>Running make for ([A-Z]/[A-Z][A-Z]/)([\w-]+/.+)|) {
      $DB::single=1;
      push @shortdistro, $2;
      push @longdistro, "$1$2";
      $seq{$shortdistro[-1]} ||= [];
    } elsif (m|[ ]{2}\Q$shortdistro[-1]\E|) {
      push @{$seq{$shortdistro[-1]}}, $_;
      my $end = 0;
      my $ok;
      if ($lines[0] =~ /[ ]{2}.+install.+\s+--\s+((?:NOT\s)?OK|NA)/) {
        $ok = $1;
        push @{$seq{$shortdistro[-1]}}, shift @lines;
        $end = 1;
      } elsif ($lines[0] =~ /[ ]{2}.+\s+--\s+((?:NOT\s)?OK|NA)/) {
        $ok = $1;
        push @{$seq{$shortdistro[-1]}}, shift @lines;
        if ($lines[0] =~ />Running.*test/
            && $lines[1] =~ />[ ]{2}/) {
          push @{$seq{$shortdistro[-1]}}, shift @lines;
          push @{$seq{$shortdistro[-1]}}, shift @lines;
          $end=1;
        }
        if ($lines[0] =~ />Running.*install/
            && $lines[1] =~ />[ ]{2}/) {
          push @{$seq{$shortdistro[-1]}}, shift @lines;
          push @{$seq{$shortdistro[-1]}}, shift @lines;
          $end=1;
        }
      }
      if ($end) {
        $i++;
        my $log = join "", map { "$_\n" } @{$seq{$shortdistro[-1]}};
        mystore($shortdistro[-1],$log,$ok,$i);
        delete $seq{$shortdistro[-1]};
        pop @longdistro;
        pop @shortdistro;
      }
      next LINE;
    }
    push @{$seq{$shortdistro[-1]}}, $_;
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
