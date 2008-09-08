

=pod

	* when EWILHELM wants to know which of these distros have (not) been
	tested with Module-Build-X.XX then we currently cannot answer the
	question for a large amount of distros, only for a few because the
	cpantesters/nntp download takes too long. But at least I could look into
	reports-sent.db, find the last Module-Build-0.2808_03 there at line
	328836 and count towards the end, which is at 339601, gives >10000
	smokes which might correspond to >1500 distros. Then I could take those
	1500 names and look them up in his list. Intersting it is, but only
	about my tests and not about strange things that might have happened. So
	we'd need to compare the ceteris paribus results of all these distros
	with MB latest stable and the _03 candidate.


Reword:

This script has downloaded and parsed 56000 recent test reports from
the cpan testers nntp server. It found 135 distros that have been
tested with both MB 0.2808_03 and 0.2808.

Collect the names of modules that we have seen results for both MB
versions:

perl -nle 'next unless /meta:about\[(.+?)\].*?mod:Module::Build\[(0\.2808(?:|_03))\]/; next if $seen{"$1 $2"}++; ++$cseen{$1}==2 and print $1' bin/count-for-ewilhelm.pl.out | wc

I hate this sort of oneliners I can never reuse. The following collects
only those results that have unambiguous results:

perl -nale 'next unless /meta:about\[(.+?)\].*?mod:Module::Build\[(0\.2808(?:|_03))\]/; $seen{$1}{$2}{$F[0]}++;END{for my $d (sort keys %seen){ next unless keys %{$seen{$d}} >= 2; for my $v (sort keys %{$seen{$d}}){ for my $ok (sort keys %{$seen{$d}{$v}}){ my $a = $c{$d}||=[]; push @$a, sprintf "%-34s %12s %-12s %3d\n", $d, $v, $ok, $seen{$d}{$v}{$ok} }}} for my $d (sort keys %c){if (@{$c{$d}}==2){print @{$c{$d}}}}}' bin/count-for-ewilhelm.pl.out

=cut

use strict;
use warnings;
use Getopt::Long;
use LWP::Simple;
use Time::HiRes qw(sleep);

our %Opt;
GetOptions(\%Opt,
           "run-ctgetreports!",
          );

mirror "http://scratchcomputing.com/tmp/generated_by.module_build.list", "tmp/generated_by.module_build.list";
my %C;
{
    open my $fh, "/home/sand/.cpanreporter/reports-sent.db" or die;
    while (<$fh>) {
        next if $. < 328836;
        my($distro) = /^\S+\s+\S+\s+(\S+)/ or next;
        $C{$distro}=1;
    }
}
{
    open my $fh, "tmp/generated_by.module_build.list" or die;
    while (<$fh>) {
        chomp;
        my($vdistro) = m|.+/([^/\s]+)| or next;
        $vdistro =~ s/\.( tar\.gz | tgz | zip ) $//x ;
        printf "%d %s\n", $C{$vdistro}||0, $_;
        if ($C{$vdistro} && $Opt{'run-ctgetreports'}) {
            my($distro) = $vdistro =~ /^(\S+)-[\d\.]+$/;
            my @system =
                (
                 "/home/src/perl/repoperls/installed-perls/perl/pVNtS9N/perl-5.8.0\@32642/bin/perl",
                 "-I",
                 "/home/k/sources/cpan-testers-parsereport/lib",
                 "/home/k/sources/cpan-testers-parsereport/bin/ctgetreports",
                 "-q",
                 "meta:about",
                 "-q",
                 "meta:from",
                 "-q",
                 "mod:Module::Build",
                 $distro,
                );
            warn "system[@system]";
            system @system;
            sleep 0.1;
        }
    }
}
