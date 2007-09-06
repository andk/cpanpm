#!/usr/bin/perl -0777 -nl


=pod

Second implementations with a state machine. Much shorter and even
correcter.

It's always an ugly step when going from text processing with console
escapes to XML processing

=cut


use strict;
use Dumpvalue;
use Encode qw(decode);
use Encode::Detect ();
use File::Path qw(mkpath);
use List::MoreUtils qw(uniq);
use Time::HiRes qw(sleep time);
use YAML::Syck;

our $VERIFY_XML = 0;
if ($VERIFY_XML) {
  require XML::LibXML;
  our $p = XML::LibXML->new;
}
our $start = time;
our($perl_path) = m|(/home\S+/installed-perls/(?:.*?)/p.*?/perl-5.*?@(?:\d+))|;
our $outdir = $ARGV;
warn "Converting '$outdir'\n";
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
  $ulog =~ s|^</span>||;
  $ulog .= q|</span>| if $ulog =~ /<span[^<>]+>[^<]+$/;
  $ulog = qq{<distro time="$time" perl="$perl_path" distro="$shortdistro" ok="$ok" seq="$seq">$ulog</distro>\n};
  if ($VERIFY_XML) {
    our $p;
    die "cannot parse '$shortdistro': [$ulog]" unless eval { $p->parse_string($ulog); 1 };
  }
  print $fh $ulog;
  close $fh or die;
  sleep 1/32;
}

sub measure ($) {
  warn sprintf "[%s] since last measure[%.4f]\n", shift, time - $start;
  sleep 1;
  $start = time;
}

# the first part is a duplication of colorterm-to-html.pl which I
# wrote for my Munich talk:

my%h=("&"=>"&amp;",q!"!=>"&quot;","<"=>"&lt;",">"=>"&gt;");
s/([&"<>])/$h{$1}/g;
measure("&\"<>");
s!\e\[1;3[45](?:;\d+)?m(.*?)\e\[0m!<span style="color: blue">$1</span>!sg;
measure("blue");
s!\e\[1;31(?:;\d+)?m(.*?)\e\[0m!<span style="color: red">$1</span>!sg;
measure("red");
#s!\n!<br/>\n!g;
s!\r\n!\n!g;
measure("CRLF");

our $HTMLSPANSTUFF = qr/(?:<[^<>]+>)*/;
{
  my @lines = split /\n/, $_;
  measure("split");
  my %seq; # $seq{$shortdistro} = [];
  my @longdistro;
  my @shortdistro;
  my $i = 0;
 LINE: while (defined($_ = shift @lines)) {
    s!.+?\r!!g;
    if (/
         \Q>Running install for module '\E
         |>\S+\Q is up to date \E\(
         /x) {
      next LINE;
    } elsif (m!<span[^<>]+>Running (?:make|Build) for (.+)!) {
      $DB::single=1;
      my $d = $1;
      $d =~ s|</span>$||;
      push @longdistro, $d;
      $d =~ s|^[A-Z]/[A-Z][A-Z]/||;
      push @shortdistro, $d;
      $seq{$shortdistro[-1]} ||= [];
    } elsif (m|[ ]{2}\Q$shortdistro[-1]\E|) {
      push @{$seq{$shortdistro[-1]}}, $_;
      my $end = 0;
      my $ok;
      if ($lines[0] =~ /[ ]{2}.+[ ]install[ ].*?--\s+((?:NOT\s)?OK|NA)/) {
        $ok = $1;
        push @{$seq{$shortdistro[-1]}}, shift @lines;
        $end = 1;
      } elsif ($lines[0] =~ /[ ]{2}.+\s+--\s+((?:NOT\s)?OK|NA)/) {
        $ok = $1;
        push @{$seq{$shortdistro[-1]}}, shift @lines;
        if ($lines[0] =~ /\bPrepending\b.*\bPERL5LIB\b/) {
          push @{$seq{$shortdistro[-1]}}, shift @lines;
        }
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
        if ($lines[0] =~ />\/\/hint\/\//) {
          push @{$seq{$shortdistro[-1]}}, shift @lines;
          push @{$seq{$shortdistro[-1]}}, shift @lines while $lines[0] =~ /^\s/;
          $end=1;
        }
      }
      if ($end) {
        $i++;
        unless ($i % 100){
          measure($i);
        }
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
