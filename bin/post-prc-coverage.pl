#!/usr/bin/perl

=pod

prg. seems to be broken by Devel::Cover 0.59



The coverage analysis of CPAN.pm is difficult to read because the
methods do not contain the package name.

Solution 1 would be to split the file, but I really like these things
kept in one editor window.

Solution 2 would be to find the option in "cover" that writes the HTML
and if it's not there, add it.

Solution 3 is to post-process the HTML. By far the simplest for me,
even if it's the ugliest.

=cut

use strict;
use warnings;

my $html = shift or die "Usage: $0 file-to-process";

my($hdir,$ppath,$type) = $html =~ m|(.+)/([^/]+)--(\w+)\.html$|;
$ppath =~ s/-pm$/.pm/ or die;
$ppath =~ s|-|/|g;
-f $ppath or die;

open my $pfh, $ppath or die;
my %line_sub_pkg;
my $curpkg = "main";
while (<$pfh>) {
  s/#.*//;
  $curpkg = $1 if /^\s*package\s+([\w:]+)/;
  if (/^sub (\w+)/) {
    for my $delta (0,1) {
      my $line = $. + $delta;
      $line_sub_pkg{"$line\:$1"} = $curpkg;
    }
  }
  last if /^__END__/;
}
close $pfh;

open my $rhfh, $html or die "Could not open $html\: $!";
open my $whfh, ">", "$html.new" or die;
while (<$rhfh>) {
  if (m|^(<tr>.*<div class="s">)(\w+)(</div></td></tr>)|) {
    my($hpre,$subr,$hpost) = ($1,$2,$3);
    my($line) = $hpre =~ /id="L(\d+)"/;
    if (my $pkg = $line_sub_pkg{"$line:$subr"}) {
      print $whfh "$hpre$pkg\::$subr$hpost\n";
    } else {
      print $whfh $_;
    }
  } else {
    print $whfh $_;
  }
}
close $rhfh;
close $whfh;
rename $html, "$html.old" or die;
rename "$html.new", $html or die;
