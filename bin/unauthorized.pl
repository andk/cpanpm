#!/usr/bin/perl

use strict;
use warnings;

use Crypt::SSLeay;
use Getopt::Long;
use HTML::TreeBuilder::XPath;
use LWP::UserAgent;
use YAML::Syck;

our %OPT;
GetOptions(\%OPT, "cred=s");

my($searchurl) = @ARGV;

sub Usage () {
  "Usage: $0 --cred credentials searchurl

e.g. --cred ANDK:geheim http://search.cpan.org/~rgarcia/perl-5.9.5/
";
}

die Usage unless $searchurl && $OPT{cred};

sub trim {
  my($x) = @_;
  $x =~ s/^\s+//;
  $x =~ s/\s+\z//;
  $x;
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
    my $pause_resp = $ua->get("https://$OPT{cred}\@pause.perl.org/pause/authenquery?pause99_peek_perms_by=me;pause99_peek_perms_query=$module;pause99_peek_perms_sub=1;OF=YAML");
    die $pause_resp->as_string unless $pause_resp->is_success;
    my $yaml = YAML::Syck::Load($pause_resp->content);
    my $owner = $yaml->[0]{owner};
    printf "%-45s %-12s\n", $module, $owner;
  }
}
