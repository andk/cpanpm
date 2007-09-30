#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use HTML::TreeBuilder::XPath;
use LWP::UserAgent;
use YAML::Syck;

our %OPT;
GetOptions(\%OPT, "cred=s");

my($searchurl) = @ARGV;

sub Usage () {
  "Usage: $0 searchurl

e.g. http://search.cpan.org/~rgarcia/perl-5.9.5/
";
}

die Usage unless $searchurl;

sub trim {
  my($x) = @_;
  $x =~ s/^\s+//;
  $x =~ s/\s+\z//;
  $x;
}

sub find_owner {
  my($mod) = @_;
  open my $fh, "/home/ftp/pub/PAUSE/modules/06perms.txt" or die;
  local $/ = "\n";
  while (<$fh>) {
    next unless /^\s*$/;
    last;
  }
  while (<$fh>) {
    s/\s*\z//;
    my($lmod,$luser,$perms) = split /,/, $_;
    next unless $lmod eq $mod;
    next if $perms eq "c";
    return $luser;
  }
}

my $ua = LWP::UserAgent->new;
my $resp = $ua->get($searchurl);
die $resp->as_string unless $resp->is_success;
my $tree = HTML::TreeBuilder::XPath->new_from_content($resp->content);
my @h2 = $tree->findnodes("//h2");
$|=1;
for my $h2 (@h2) {
  next unless $h2->findvalue(".") =~ /Modules/;
  my($table) = $h2->findnodes("../table");
  my @rows = $table->findnodes(".//tr");
  for my $row (@rows) {
    my($td3) = $row->findnodes("./td[3]");
    next unless $td3->findvalue(".") =~ /UNAUTHORIZED/;
    my($td1) = $row->findnodes("./td[1]");
    my $td1_string = $td1->findvalue(".");
    my $module = trim $td1_string;
    my $owner = find_owner($module);
    printf "%-45s %-12s\n", $module, $owner;
  }
}
