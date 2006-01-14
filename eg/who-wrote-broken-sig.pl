


=pod

This script investigates a list of broken CPAN distros

=cut

use lib 'lib';
use CPAN 1.8058; # 1.80 broken for *.tgz
use Cwd qw(cwd);
use File::Path qw(rmtree);
my $cwd = cwd;
my @brokensig = qw(
B/BM/BMORROW/PerlIO-nline-0.03.tar.gz                                   # 16844
B/BO/BOBMATH/Crypt-CAST5_PP-1.03.tar.gz                                 # 16845; got reply
B/BU/BURAK/CGI-Auth-Basic-1.02.tar.gz                                   # bugreport Module::Signature sent to Aurey
B/BU/BURAK/GD-SecurityImage-1.583.tar.gz                                # ditto
B/BU/BURAK/MP3-M3U-Parser-2.1.tar.gz                                    # ditto
C/CR/CRAIHA/Geo-Coordinates-Parser-0.01.tar.gz                          # 16846
D/DA/DARREN/Text-TabularDisplay-1.21.tar.gz                             # 16847
D/DM/DMAKI/Class-Validating-0.02.tar.gz                                 # 16848
D/DM/DMAKI/DateTime-Event-Lunar-0.04.tar.gz                             # dto
D/DM/DMAKI/DateTime-Util-Astro-0.06.tar.gz                              # dto
D/DM/DMAKI/POE-Component-StackedProcessor-0.05.tar.gz                   # dto
D/DR/DROLSKY/DateTime-Format-HTTP-0.36.tar.gz                           # dto
G/GO/GOZER/Scalar-Readonly-0.01.tar.gz                                  # 16849
J/JJ/JJORE/B-Lisp-0.01.tar.gz                                           # 16850
J/JJ/JJORE/Geo-TigerLine-Abbreviations-0.02.tar.gz                      # dto
J/JM/JMEHNLE/apache-auth-userdb/Apache-Auth-UserDB-0.11.tar.gz          # 16851
J/JM/JMEHNLE/clamav-client/ClamAV-Client-0.11.tar.gz                    # dto
J/JM/JMEHNLE/courier-filter/Courier-Filter-0.17.tar.gz                  # dto
J/JM/JMEHNLE/net-address-ipv4-local/Net-Address-IPv4-Local-0.12.tar.gz  # dto
J/JM/JMEHNLE/www-restaurant-menu/WWW-Restaurant-Menu-0.11.tar.gz        # dto
K/KC/KCLARK/SQL-Translator-0.07.tar.gz                                  # 16852
K/KM/KMELTZ/SSN-Validate-0.13.tar.gz                                    # 16853
K/KU/KUDARASP/PHP-Strings-0.28.tar.gz                                   # 16854
L/LO/LORENSEN/Net-BGP-0.08.tar.gz                                       # 16855
N/NI/NIKC/SVN-Web-0.42.tar.gz                                           # 16856
P/PT/PTANDLER/PBib/Bundle-PBib-2.08.01.tar.gz                           # 16857
P/PT/PTANDLER/PBib/Bundle-PBib-2.08.tar.gz                              # dto
R/RE/REEDFISH/Term-Menus-1.11.tar.gz                                    # 16858
R/RR/RRWO/Acme-AutoColor-0.01.tar.gz                                    #
R/RR/RRWO/Acme-Mobile-Therbligs-0.04.tar.gz                             #
R/RR/RRWO/Algorithm-ScheduledPath-0.41.tar.gz                           #
R/RR/RRWO/Algorithm-SkipList-1.02.tar.gz                                #
R/RR/RRWO/CPAN-Mini-Tested-0.22.tar.gz                                  #
R/RR/RRWO/CPAN-YACSmoke-0.03.tar.gz                                     #
R/RR/RRWO/CPAN-YACSmoke-Plugin-Phalanx100-0.02.tar.gz                   #
R/RR/RRWO/File-HomeDir-Win32-0.03.tar.gz                                #
R/RR/RRWO/Graphics-ColorNames-1.06.tar.gz                               #
R/RR/RRWO/Log-Dispatch-Win32EventLog-0.13.tar.gz                        #
R/RR/RRWO/Logic-Kleene-0.05.tar.gz                                      #
R/RR/RRWO/Module-Phalanx100-0.05.tar.gz                                 #
R/RR/RRWO/Mozilla-Backup-0.06.tar.gz                                    #
R/RR/RRWO/Params-Smart-0.06.tar.gz                                      #
R/RR/RRWO/Pod-Readme-0.05.tar.gz                                        #
R/RR/RRWO/Text-Truncate-1.03.tar.gz                                     #
R/RR/RRWO/Tie-RangeHash-1.03.tar.gz                                     #
R/RR/RRWO/Tie-RegexpHash-0.13.tar.gz                                    #
R/RR/RRWO/Tree-Node-0.06.tar.gz                                         #
R/RR/RRWO/Win32-EventLog-Carp-1.39.tar.gz                               #
S/SC/SCHUMACK/CircuitLayout-0.07.tar.gz                                 # 16859
S/SI/SIMON/Lingua-EN-Keywords-2.0.tar.gz                                #
S/SI/SIMON/Mail-Miner-2.7.tar.gz                                        #
);
my $fh;
open $fh, ">", "$0.out" or die;

DISTRO: for $s (@brokensig){
  my $d = CPAN::Shell->expand("Distribution",$s);
  unless ($d) {
    $d = CPAN::Distribution->new(ID => $s);
  }
  my $id = $d->id;
  print "---->[$id]<----\n";
  eval {$d->get;};
  $d->look;
  my $dir = $d->dir or die;
  rmtree $dir;
  last;
}

__END__
# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
