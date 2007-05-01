#!/usr/bin/perl -0777 -nl

use strict;
use File::Path qw(mkpath);
use List::MoreUtils qw(uniq);
our($perl_path) = m|(\S+/installed-perls/(?:.*?)/p.*?/perl-5.*?@(?:\d+))|;
our $outdir = $ARGV;
$outdir =~ s/.out$/.d/ or die;
mkpath $outdir;

sub mystore ($$$){
  my($shortdistro,$log,$ok) = @_;
  my $outfile = $shortdistro;
  $outfile =~ s!\.(tar.gz|tgz|tar.bz2|tbz|zip)$!!;
  $outfile =~ s|/|!|g;
  $outfile =~ s|^|$outdir/|;
  my($time) = $outdir =~ /(\d{8}T\d{4})/;
  open my $fh, ">", $outfile or die;
  print $fh qq{<distro time="$time" perl="$perl_path" distro="$shortdistro" ok="$ok">};
  print $fh $log;
  print $fh "</distro>\n";
  close $fh or die;
}

# the first part is a duplication of colorterm-to-html.pl which I
# wrote for my Munich talk:
s!\&!\&amp;!g;
s!"!&quot;!g;
s!<!&lt;!g;
s!>!&gt;!g;
s!\e\[1;3[45](?:;\d+)?m(.*?)\e\[0m!<span style="color: blue">$1</span>!sg;
s!\e\[1;31(?:;\d+)?m(.*?)\e\[0m!<span style="color: red">$1</span>!sg;
#s!\n!<br/>\n!g;
s!\r\n!\n!g;
s!.+\r!!g;

=pod

lines like

  CPAN.pm: Going to build (A/AB/ABH/XML-RSS-1.22.tar.gz)

can occur once or twice. The latter means dependencies get in the way
and between the first and second occurrence there are the dependencies.

$1 is the distro.

From the second occurrence (or if there is only one, from the first)
until the consecutive two lines

  /^$HTMLSPANSTUFF {2}(.+)\n$HTMLSPANSTUFF {2}.+install.+\s+--\s(NOT )?OK$/

we expect the data for exactly this distro. $1 is again the distro.

=cut

our $HTMLSPANSTUFF = qr/(?:<[^<>]+>)*/;
{
  my %N;
  my %S;
  my @distros = uniq map { $S{$_}++; $_ } /^  CPAN\.pm: Going to build (.*)/mg;
  while (my $d = pop @distros) {
    if ($S{$d} == 2) {
      m/^  CPAN\.pm: Going to build $d/gc;
      warn sprintf "FOUND FIRSTMATCH %s at %d\n", $d, pos $_;
    }
    my $shortdistro = $d;
    $shortdistro =~ s!^[A-Z]/[A-Z][A-Z]/!!;
    if (
        s/
          (\G[\s\S]+)
          (
          <span[^<>]+>
          Running[ ](?:make|Build)[ ]for[ ]\Q$d\E\n
          [\s\S]+\n
          ^[ ][ ]CPAN\.pm:[ ]Going[ ]to[ ]build[ ]\Q$d\E\n
          [\s\S]*\n
          ^$HTMLSPANSTUFF[ ]{2}(?:\Q$shortdistro\E)\n
          $HTMLSPANSTUFF[ ]{2}.+\s+--\s+((?:NOT\s)?OK)\n
          <\/span>
         )/$1/mx
       ) {
      my($log,$ok) = ($2,$3);
      warn sprintf "FOUND: %s\n", $d, $S{$d}, length($log);
      mystore($shortdistro,$log,$ok);
    } else {
      warn "NOT found: $d\n";
      $N{$d}++;
    }
  }
  pos($_) = 0;
  map {$N{$_}++} />Running \S+ for ([A-Z]\/.*)/mg;
  for my $d (keys %N) {
    my $shortdistro = $d;
    $shortdistro =~ s!^[A-Z]/[A-Z][A-Z]/!!;
    if (
        s/
          (
          <span[^<>]+>
          Running[ ](?:make|Build)[ ]for[ ]\Q$d\E\n
          [\s\S]+\n
          ^$HTMLSPANSTUFF[ ]{2}(?:\Q$shortdistro\E)\n
          $HTMLSPANSTUFF[ ]{2}.+\s+--\s+((?:NOT\s)?OK)\n
          <\/span>
         )//mx
       ) {
      my($log,$ok) = ($1,$2);
      warn sprintf "FINALLY FOUND: %s\n", $d, $S{$d}, length($log);
      mystore($shortdistro,$log,$ok);
    } else {
      warn "AGAIN NOT FOUND: $d\n";
    }
  }
}

open my $rfh, ">", "$outdir/residuum.txt" or die;
print $rfh $_;
close $rfh or die;


=pod

This is the data we want to gather:

	distribution            MIYAGAWA/XML-Atom-1.2.3.tar.gz
	perl                    /home/src/perl/..../perl              !reveals maint vs perl
	logfile (=date)         megainstall.20070422T1717.out
	ok                      OK or "make_test NO" or something
	log_as_xml

So if we take the input filename, s/.out/.d/ on it and make that a
directory, we have the storage area and the first metadata. If we then
write a file "perl" with the path to perl, we have the second metadata
thing. We should really store the output of '$perl -V' there, just in
case.

If we then use the distroname and replace slashes with bangs, we have
a good flat filename. We could then even s|!.+!|!| for the filename if
we keep the original distroname for inside. We could write

  <distro time="$time" perl="$perl_path" distro="$distro_orig">
  $report
  </distro>

and of course, we must escape properly.


=cut

