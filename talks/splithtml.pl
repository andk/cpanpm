#!/usr/bin/perl

=pod

from my history I can reconstruct:

    1 for f in gpw9-cpan-talk.d/*.html; do\necho '<!--\n Local Variables:\n mode: nxml\n coding: utf-8\n End:\n-->\n'\ndone
    1 perl -i -ple 's!uparr.*?alt="next"!uparrow.gif" align="right" border="0" alt="content"!;' gpw9-cpan-talk.d/*.html
    1 for f in gpw9-cpan-talk.d/*.html; do\necho '<!--\n Local Variables:\n mode: nxml\n coding: utf-8\n End:\n-->\n' >>| $f\ndone
    1 perl -i -ple 's!<meta http-equiv="Content-Type" content="text/html; charset=utf-8">!<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>!' gpw9-cpan-talk.d/*.html
    1 perl -i -ple 's!border="0">!border="0" alt="next"/>!;s!border="0">!border="0" alt="content"/>!;s!border="0">!border="0" alt="previous"/>!;' gpw9-cpan-talk.d/*.html
    1 perl -i -ple 's!<font size="6">!<div style="font-size: 24">!' gpw9-cpan-talk.d/*.html
    1 perl -i -ple 's!<html>!<html xmlns="http://www.w3.org/1999/xhtml">!' gpw9-cpan-talk.d/*.html
    1 perl -i -ple 's!leftarr.*?alt="content"!leftarrow.gif" align="right" border="0" alt="previous"!;' gpw9-cpan-talk.d/*.html

All that was probably only related to the slides I made from
megainstall*.xml files but I keep it here as a reminder in case
unforeseen things happen.

I wonder headlines have different sizes:

small: 2 4 6 7 8

big: 1 3 5 9 10

Urps, this was all from one of the trials at home that I considered
broken and did not notice that one of those wrote into the *.d
directory. But the Pod::Simple::HTML does everything so different that
the whole script here has to be rewritten.

Very difficult seems to me the URL translation to links.
Pod::Simple::HTML sems to have done it partially. Yes, it does it for
DTs. We have three DTs: http://log.cpan.org, ...use.perl.org...,
...rt.cpan.org... Ahhh, but these are only A NAMES, which we do not
need. And the difference in the POD is that these three have no star
after the '=item'. Strange.

=cut

use strict;
use warnings;
use File::Copy qw(cp);

my $DEBUG = 1;

my $base = shift or die "Usage: $0 base";
mkdir "$base.d" unless -d "$base.d";
for my $p (qw(left right up)) {
  my $file = sprintf "%sarrow.gif", $p;
  my $tofile = "$base.d/$file";
  cp $file, $tofile unless -f $tofile;
}
open my($fh), "$base.html" or die "could not open '$base.html'";
warn "opened '$base.html'" if $DEBUG;
open my($fhi), ">", "$base.d/k0.html" or die "Couldn't open $base.d/k0.html";
warn "opened > '$base.d/k0html'" if $DEBUG;
print $fhi qq{<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html">
<title></title>
</head>
<body bgcolor="#ffffff">
<font size="5">
<h1>Index</h1>
<ul>
};
local $/;
my $html = <$fh>;
warn sprintf "slurped %d bytes from html file", length $html if $DEBUG;
my @html = split m|(<h1>.*?</h1>)|s, $html;
warn sprintf "found %d chunks in html", scalar @html;
shift @html;
my $lastchap = int(@html/2);
my $chap = 0;
my $idxonly = 0;
while (@html) {
  my($head) = shift @html;
  my($body) = shift @html;
  $chap++;
  # print "$chap: $head\n";
  my $fh;
  unless ($idxonly){
    open $fh, ">:utf8", "$base.d/k$chap.html" or die "Could not open ....";
    print $fh qq{<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title></title>
</head>
<body bgcolor="#ffffff">
<font size="6">
<hr />
};
    if ($chap < $lastchap) {
      printf $fh qq{<a href="k%d.html"><img src="rightarrow.gif" align="right" border="0"></a>\n}, $chap+1; #};
    }
    print $fh qq{<a href="k0.html"><img src="uparrow.gif" align="right" border="0"></a>}; # };
    if ($chap > 1) {
      printf $fh qq{<a href="k%d.html"><img src="leftarrow.gif" align="right" border="0"></a>}, $chap-1;
    }
    $head =~ s/<h1><a .+?>/<h1>/s;
    $head =~ s|</a></h1>|</h1>|s;
    $body =~ s|(http://[^<>\s]+)|<a href="$1">$1</a>|g;
    print $fh $head, $body, qq{</font></body></html>\n}; #};
  }
  my $ind = $head;
  $ind =~ s/^.*?<h1><a class.*?>//s;
  $ind =~ s|</a></h1>.*||;
  printf $fhi qq{<li><a href="k%d.html">%s</a></li>}, $chap, $ind; #};
}
print $fhi qq{
</ul>
</font></body></html>\n};
