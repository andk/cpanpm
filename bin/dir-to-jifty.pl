#!/usr/local/perl-m-5.8.0@31162/bin/perl

use strict;
use warnings;
use UNIVERSAL::require;
use Jifty::ClassLoader ();
BEGIN {
    Jifty::Util->require or die $UNIVERSAL::require::ERROR;
    my $root = Jifty::Util->app_root;
    unshift @INC, "$root/lib" if ($root);
}
use Jifty;
my $cl = Jifty::ClassLoader->new (base => "Pocpoc");
$cl->require;
my $j = new Jifty; # sets up database connection and other stuff

use FindBin ();
use XML::LibXML;

my $logdir = shift || "$FindBin::Bin/../logs";
opendir my $dh, $logdir or die "cannot opendir '$logdir': $!";

my $p = XML::LibXML->new;
my $i = 0;
$|=1;
SESSION: for my $dirent (sort { $b cmp $a } readdir $dh) {
  next if $dirent =~ /^\./;
  my $abs = "$logdir/$dirent";
  next unless $abs =~ /(?:^|\/)megainstall\.(\d+T\d+)\.d(?:\/|$)/;
  my $starttime = $1;
  opendir my $dh2, $abs or die "cannot opendir: '$abs': $!";
  my($total,$failed);
  $total = 0;
  $failed = 0;
  my @readdir2 = sort grep { /\.xml$/ } readdir $dh2;
  print "\@";
  my $s = Pocpoc::Model::Session->new(handle => Jifty->handle);
 TESTRUN: for my $i (0..$#readdir2) {
    my $dirent2 = $readdir2[$i];
    my $xfile = "$abs/$dirent2";
    my $xml = $p->parse_file($xfile);
    my($ok,$seq,$perl,$distro,$branch,$patchlevel);
    $ok = $xml->findvalue("/distro/\@ok");
    $seq = $xml->findvalue("/distro/\@seq") || 0;
    $perl = $xml->findvalue("/distro/\@perl");
    $distro = $xml->findvalue("/distro/\@distro");
    my $d = Pocpoc::Model::Distro->new(handle => Jifty->handle);
    ($branch,$patchlevel) = $perl =~ m|/installed-perls/(.*?)/p.*?/perl-5.*?@(\d+)|;
    $total++;
    $failed++ unless $ok eq "OK";
    $s->load_or_create(
                       starttime => $starttime,
                       perl => $perl,
                       branch => $branch,
                       patchlevel => $patchlevel,
                      );
    $d->load_or_create(
                       name => $distro,
                      );
    if ($i == 0) {
      my $total = $s->total || 0;
      if ( $total == @readdir2 ) {
        print "_";
        next SESSION;
      } else {
        print "($dirent)";
      }
    }
    print "+";
    unless ($i % 64){
      print "($total/$#readdir2)";
    }
    my $t = Pocpoc::Model::Testrun->new(handle => Jifty->handle);
    $t->load_or_create(
                       distro => $d,
                       testsession => $s,
                      );
    $t->set_seq($seq);
    $t->set_testresult($ok);
  }
  $s->set_failed($failed);
  $s->set_total($total);
  my $vtotal = $s->total;
  unless ($vtotal == $total) {
    die "Sanity check broke: total[$total]vtotal[$vtotal]";
  }
  my $vfailed = $s->failed;
  unless ($vfailed == $failed) {
    die "Sanity check broke: failed[$failed]vfailed[$vfailed]";
  }
}


=pod

/usr/bin/perl -le 'use DBI; my $db = shift or die;my $dbh = DBI->connect("dbi:SQLite:dbname=$db","","") or die;my $sth = $dbh->prepare("select * from testruns");$sth->execute;while (my @row = $sth->fetchrow){  print "row[@row]";}' poce | head
row[1 /home/src/perl/cpan-sql-stuff/CPAN-SQLite/. 1 0 OK]
row[2 /home/src/perl/tk/SVN/. 1 0 OK]
row[3 ABH/XML-RSS-1.22.tar.gz 1 0 OK]
row[4 ABIGAIL/Regexp-Common-2.120.tar.gz 1 0 OK]
row[5 ABW/Class-Singleton-1.03.tar.gz 1 0 OK]
row[6 ACALPINI/Lingua-Stem-It-0.01.tar.gz 1 0 OK]
row[7 ADAMK/Algorithm-Dependency-1.102.tar.gz 1 0 OK]
row[8 ADAMK/AppConfig-1.64.tar.gz 1 0 OK]
row[9 ADAMK/Archive-Zip-1.18.tar.gz 1 0 OK]
row[10 ADAMK/CPAN-Inject-0.05.tar.gz 1 0 NOT OK]

==cut
