#!/usr/bin/perl -0777 -nl

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
  $ulog =~ s/([\x00-\x09\x0b\x0c\x0e-\x1f])/ $dumper->stringify($1) /ge;
  print $fh qq{<distro time="$time" perl="$perl_path" distro="$shortdistro" ok="$ok" seq="$seq">};
  print $fh $ulog;
  print $fh "</distro>\n";
  close $fh or die;
  sleep 1/4;
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
  my @logs = ($_);
  my @residua;
  my %seq;
  while ($_ = shift @logs) {
    my @distros = uniq /^  CPAN\.pm: Going to build (.*)/mg;
    unless (keys %seq) {
      # on the first run we can determine the absolute position within
      # the file for all distros of that session
      %seq = map { $distros[$_] => $_+1 } 0..$#distros;
    }
    warn sprintf(
                 "NEW LOG length %d, unprocessed logs ATM: %d, expected distros here: %d",
                 length($_),
                 scalar(@logs),
                 scalar(@distros),
                );
    sleep 1;
    while (my $d = pop @distros) {
      # my $d = splice @distros, int(scalar(@distros)/2), 1;
      my $shortdistro = $d;
      $shortdistro =~ s!^[A-Z]/[A-Z][A-Z]/!!;
      if (
          s/
          (
          <span[^<>]+>
          Running[ ](?:install|make|Build)[ ]for[ ]\Q$d\E\n
          [\s\S]+\n
          ^[ ][ ]CPAN\.pm:[ ]Going[ ]to[ ]build[ ]\Q$d\E\n
          [\s\S]+\n
          ^$HTMLSPANSTUFF[ ]{2}(?:\Q$shortdistro\E)\n
          $HTMLSPANSTUFF[ ]{2}.+\s+--\s+((?:NOT\s)?OK|NA)\n
          <\/span>
         )//mx
         ) {
        my $log = $1;
        my $ok  = $2;
        my @distros_under = uniq $log =~ /^  CPAN\.pm: Going to build (.*)/mg;
        if (@distros_under == 1) {
          warn sprintf "FOUND: %s (%d)\n", $d, length($log);
          mystore($shortdistro,$log,$ok,$seq{$d});
        } elsif (length $_ == 0) { # exhausted
          push @residua, $log;
        } else {
          push @logs, $log;
        }
      }
    } # while @distros
    push @residua, $_ if length $_;
    open my $rfh, ">", "$outdir/residuum.yml" or die;
    print $rfh YAML::Syck::Dump(\@residua);
    close $rfh or die;
  } # while @logs
}


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

BUGS:

BUG1

we should recognize when a distro reaches "delayed until after
prerequisites", write this first piece into the splitted logfile and
append the other part.


  </span><span style="color: blue">Running install for module 'Archive::Zip'
  </span><span style="color: blue">Running make for A/AD/ADAMK/Archive-Zip-1.18.tar.gz
  </span><span style="color: blue">Checksum for /home/k/.cpan/sources/authors/id/A/AD/ADAMK/Archive-Zip-1.18.tar.gz ok
  </span>Archive-Zip-1.18/
  Archive-Zip-1.18/t/
  [...]
  <span style="color: blue">
    CPAN.pm: Going to build A/AD/ADAMK/Archive-Zip-1.18.tar.gz

  </span>Warning: prerequisite File::Which 0.05 not found.
  Checking if your kit is complete...
  Looks good
  Writing Makefile for Archive::Zip
  <span style="color: blue">---- Unsatisfied dependencies detected during ----
  ----       ADAMK/Archive-Zip-1.18.tar.gz      ----
      File::Which [requires]
  </span><span style="color: blue">Running make test
  </span><span style="color: blue">  Delayed until after prerequisites
  </span><span style="color: blue">Running make install
  </span><span style="color: blue">  Delayed until after prerequisites


BUG2

When we reached megainstall.20070406T1526.out this program started to
become extremely slow. 11 hourse between the two timestamps:

  -rw-rw-r--   1 sand sand  5060 Apr 28 16:54 DMAKI!DateTime-Util-Calc-0.13
  -rw-rw-r--   1 sand sand  3566 Apr 29 04:05 DMAKI!DateTime-Util-Astro-0.08

Ah, this was an endless loop in CPAN.pm and DateTime-Util-Astro was
built again and again.


THE NEW ALGORITHM:

Start a new array @logs which starts out as ($_). Cut a
single-distro-log out (Matrushka2). If it does not contain further
logs, write it to disk, otherwise push it onto @logs. Continue until
you have tried all candidates.

The game ends when we reach the end of @logs. Then @logs will be an
array of residua which we shall dump for further considerations.

BUG3

encoding not clear on AWRIGLEY/HTML-Summary-0.017 and illegal
codepoint 27

This test is obviously writing test output in multiple encodings. It's
certainly not our goal to detect each test's encoding. But we need
legal output.

So I must do something to unctrl the control characters and to detect
the encoding when we have high bits set. And if detect does not
succeed, I think I can without further considerations pretend latin-1.

Before I do that I need a list of broken XML files.

    find logs -name "*.xml" -exec make mega-validate MEGA_XML={} \; >& mega-validate.out

BUG4

residuum still reveals bad "return"s in CPAN.pm that leave us no clue
where to cut the log.


=cut

