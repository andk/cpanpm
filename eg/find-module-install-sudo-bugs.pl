


=pod

This script investigates all CPAN distros if they contain
inc/Module/Install/AutoInstall.pm but not
inc/{Module,ExtUtils}/AutoInstall.pm. We wanted to write these authors
hat they should upgrade their distris with a newer release of
Module::Install.

This exercise was amazing as it revealed several unrelated bugs like
broken signatures and distros that could not be untarred for some
reason. And bugs in CPAN.pm that did not react adequatly to certain
error conditions.

=cut

use lib 'lib';
use CPAN 1.81; # 1.80 broken for *.tgz
use Cwd qw(cwd);
use File::Path qw(rmtree);
my $restart_after;
if (-f "$0.out") {
  open my $fh, "$0.out" or die;
  while (<$fh>) {
    chomp;
    $restart_after = $_;
  }
}
my $cwd = cwd;
my @brokensig = qw(
A/AU/AUTRIJUS/Lingua-ZH-TaBE-0.06.tar.gz
A/AU/AUTRIJUS/Parse-SVNDiff-0.03.tar.gz
B/BM/BMORROW/PerlIO-nline-0.03.tar.gz
B/BO/BOBMATH/Crypt-CAST5_PP-1.03.tar.gz
B/BU/BURAK/CGI-Auth-Basic-1.02.tar.gz
B/BU/BURAK/GD-SecurityImage-1.583.tar.gz
B/BU/BURAK/MP3-M3U-Parser-2.1.tar.gz
C/CR/CRAIHA/Geo-Coordinates-Parser-0.01.tar.gz
D/DA/DARREN/Text-TabularDisplay-1.21.tar.gz
D/DM/DMAKI/Class-Validating-0.02.tar.gz
D/DM/DMAKI/DateTime-Event-Lunar-0.04.tar.gz
D/DM/DMAKI/DateTime-Util-Astro-0.06.tar.gz
D/DM/DMAKI/POE-Component-StackedProcessor-0.05.tar.gz
D/DR/DROLSKY/DateTime-Format-HTTP-0.36.tar.gz
G/GO/GOZER/Scalar-Readonly-0.01.tar.gz
J/JJ/JJORE/B-Lisp-0.01.tar.gz
J/JJ/JJORE/Geo-TigerLine-Abbreviations-0.02.tar.gz
J/JM/JMEHNLE/apache-auth-userdb/Apache-Auth-UserDB-0.11.tar.gz
J/JM/JMEHNLE/clamav-client/ClamAV-Client-0.11.tar.gz
J/JM/JMEHNLE/courier-filter/Courier-Filter-0.17.tar.gz
J/JM/JMEHNLE/net-address-ipv4-local/Net-Address-IPv4-Local-0.12.tar.gz
J/JM/JMEHNLE/www-restaurant-menu/WWW-Restaurant-Menu-0.11.tar.gz
K/KC/KCLARK/SQL-Translator-0.07.tar.gz
K/KM/KMELTZ/SSN-Validate-0.13.tar.gz
K/KU/KUDARASP/PHP-Strings-0.28.tar.gz
L/LO/LORENSEN/Net-BGP-0.08.tar.gz
N/NI/NIKC/SVN-Web-0.42.tar.gz
P/PT/PTANDLER/PBib/Bundle-PBib-2.08.01.tar.gz
P/PT/PTANDLER/PBib/Bundle-PBib-2.08.tar.gz
R/RE/REEDFISH/Term-Menus-1.11.tar.gz
R/RR/RRWO/Acme-AutoColor-0.01.tar.gz
R/RR/RRWO/Acme-Mobile-Therbligs-0.04.tar.gz
R/RR/RRWO/Algorithm-ScheduledPath-0.41.tar.gz
R/RR/RRWO/Algorithm-SkipList-1.02.tar.gz
R/RR/RRWO/CPAN-Mini-Tested-0.22.tar.gz
R/RR/RRWO/CPAN-YACSmoke-0.03.tar.gz
R/RR/RRWO/CPAN-YACSmoke-Plugin-Phalanx100-0.02.tar.gz
R/RR/RRWO/File-HomeDir-Win32-0.03.tar.gz
R/RR/RRWO/Graphics-ColorNames-1.06.tar.gz
R/RR/RRWO/Log-Dispatch-Win32EventLog-0.13.tar.gz
R/RR/RRWO/Logic-Kleene-0.05.tar.gz
R/RR/RRWO/Module-Phalanx100-0.05.tar.gz
R/RR/RRWO/Mozilla-Backup-0.06.tar.gz
R/RR/RRWO/Params-Smart-0.06.tar.gz
R/RR/RRWO/Pod-Readme-0.05.tar.gz
R/RR/RRWO/Text-Truncate-1.03.tar.gz
R/RR/RRWO/Tie-RangeHash-1.03.tar.gz
R/RR/RRWO/Tie-RegexpHash-0.13.tar.gz
R/RR/RRWO/Tree-Node-0.06.tar.gz
R/RR/RRWO/Win32-EventLog-Carp-1.39.tar.gz
S/SA/SAMV/Parse-SVNDiff-0.03.tar.gz
S/SC/SCHUMACK/CircuitLayout-0.07.tar.gz
S/SC/SCHUMACK/
S/SI/SIMON/Lingua-EN-Keywords-2.0.tar.gz
S/SI/SIMON/Mail-Miner-2.7.tar.gz
S/SM/SMUELLER/Acme-Chef-1.00.tar.gz
S/SM/SMUELLER/
);

my @brokendist = qw(
B/BC/BCH/Win32-Filenames-0.01.tar.gz
B/BR/BRUNODIAZ/Finance-Bank-ES-INGDirect-0.02.tar.gz
D/DA/DAOTOAD/Log-WithCallbacks-1.00.tar.gz
D/DE/DENKINGER/Games-Poker-HistoryParser-1.3.tar.gz
E/EC/ECASTILLA/DBIx-PasswordIniFile-1.1.tar.gz
J/JO/JONATHAN/Math-Calculus-TaylorEquivalent-0.1.tar.gz
J/JO/JONATHAN/Math-Calculus-TaylorSeries-0.1.tar.gz
K/KO/KOKOGIKO/Location-GeoTool-Plugin-Locapoint-0.01.tar.gz
M/MA/MARKWIN/CNC-Cog-0.06.tar.gz
N/NI/NILSONSFJ/subs-parallel-0.07.tar.gz
P/PH/PHOENIXL/extensible_report_generator_1.13.zip
R/RV/RVOSA/Bio-Phylo-0.04.tar.gz
);

for my $x (@brokensig,@brokendist) {
  if ($restart_after) {
    if ($x gt $restart_after) {
      $restart_after = $x;
    }
  } else {
    $restart_after = $x;
  }
}

DISTRO: for $d (CPAN::Shell->expand("Distribution","/./")){
  my $id = $d->id;
  next if $restart_after && $id le $restart_after;
  print "---->[$id]<----\n";
  next DISTRO if grep {$_ eq $id or
                ( m/\/$/ && substr($id,0,length($_)) eq $_)
               } @brokensig, @brokendist;
  $d->get;
  my $dir = $d->dir or die;
  if (-f "$dir/inc/Module/Install/AutoInstall.pm"
      &&
      ! -f "$dir/inc/Module/AutoInstall.pm"
      &&
      ! -f "$dir/inc/ExtUtils/AutoInstall.pm"){
    open my $rfh, ">>", "$cwd/$0.out" or die "Cannot open >$cwd/$0.out: $!";
    print $rfh $d->id, "\n";
    close $rfh;
  }
  rmtree $dir;
}

__END__
# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
