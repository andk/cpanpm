use strict;
use warnings;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
my @want_config = qw();
# my @want_config = qw(byteorder libc gccversion intsize use64bitint archname optimize);
while (<DATA>) {
    my($ok,$id) = /(PASS|FAIL)\s+(\d+)/ or next;
    my $target = "nntp-testers/$id";
    unless (-e $target) {
        $ua->mirror("http://www.nntp.perl.org/group/perl.cpan.testers/$id",$target);
    }
    open my $fh, $target or die;
    my(%extract);
    my $mbiv;
    my $dtv;
    while (<$fh>) {
        for my $want (@want_config) {
            if (/\Q$want\E=(\S+)/) {
                my $cand = $1;
                if ($cand =~ /^'/) {
                    my($cand2) = /\Q$want\E=('(\\'|[^'])*')/;
                    if ($cand2) {
                        $cand = $cand2;
                    } else {
                        die "something wrong in id[$id]want[$want]";
                    }
                }
                
                $cand =~ s/,$//;
                $extract{$want} = $cand;
            }
        }
        if (/Math::BigInt \s+ 1.66 \s+ ([\d.]+)/x) {
            $mbiv = $1;
        } elsif (/Math::BigInt \s+ ([\d.]+) \s+ 1.66/x) {
            $mbiv = $1;
        }
        if (/DateTime \s+ 0.31 \s+ ([\d.]+)/x) {
            $dtv = $1;
        } elsif (/DateTime \s+ ([\d.]+) \s+ 0.31/x) {
            $dtv = $1;
        }
    }
    my $diag = "";
    for my $want (@want_config) {
        my $have  = $extract{$want} || "[UNDEF]";
        $diag .= "$want\[$have]";
    }
    if ($mbiv) {
        $diag .= "Math::BigInt[$mbiv]";
    }
    if ($dtv) {
        $diag .= "DateTime[$dtv]";
    }
    print "ok[$ok]id[$id]$diag\n";
}
__END__
    * FAIL 1109474 5.8.8 patch 33008 on Linux 2.6.22-1-k7 (i686-linux)
    * FAIL 1109348 5.11.0 patch 33423 on Linux 2.6.22-1-k7 (i686-linux)
    * FAIL 1105921 5.8.8 patch 33430 on Linux 2.6.22-1-k7 (i686-linux-thread-multi)
    * PASS 1101359 5.11.0 patch 33423 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 1040401 5.10.0 on Solaris 2.9 (sun4-solaris-thread-multi)
    * PASS 1039089 5.10.0 on Linux 2.4.27-3-686 (i686-linux-thread-multi)
    * PASS 1038958 5.10.0 on Freebsd 6.2-release (i386-freebsd-thread-multi)
    * PASS 1038804 5.10.0 on Netbsd 2.1.0_stable (alpha-netbsd)
    * PASS 1038800 5.10.0 on Darwin 8.10.1 (darwin-thread-multi-2level)
    * PASS 1038242 5.10.0 on Linux 2.6.23.1-slh64-smp-32 (x86_64-linux)
    * FAIL 1023000 5.8.8 on Linux 2.6.9-55.0.9.elsmp (i386-linux-thread-multi)
    * FAIL 980394 5.8.8 on Linux 2.6.9-55.0.9.elsmp (i386-linux-thread-multi)
    * PASS 978066 5.8.8 patch 33008 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 964775 5.11.0 on Linux 2.6.22-1-k7 (i686-linux)
    * FAIL 957042 5.8.8 on Linux 2.6.9-55.0.9.elsmp (i386-linux-thread-multi)
    * FAIL 941766 5.10.0 on MSWin32 5.00 (MSWin32-x86-multi-thread)
    * PASS 920121 5.10.0 on Linux 2.6.22.10 (x86_64-linux-thread-multi-ld)
    * FAIL 910565 5.10.0 on Linux 2.6.23.1luckyseven (i686-linux)
    * FAIL 907529 5.10.0 on Darwin 8.11.0 (darwin-2level)
    * PASS 904557 5.10.0 on Freebsd 6.2-release (amd64-freebsd-thread-multi)
    * PASS 904163 5.10.0 on Freebsd 6.2-release (amd64-freebsd)
    * PASS 881559 5.11.0 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * FAIL 876028 5.11.0 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 866600 5.8.8 on Darwin 8.8.1 (darwin-thread-multi-2level)
    * PASS 858682 5.8.8 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858665 5.8.7 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858662 5.8.6 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858661 5.8.5 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858660 5.8.4 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858659 5.8.3 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858658 5.8.2 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858656 5.8.1 on Darwin 8.10.0 (darwin-thread-multi-2level)
    * PASS 858649 5.10.0 on Darwin 8.10.0 (darwin-thread-multi-64int-2level)
    * PASS 854071 5.8.8 on Linux 2.6.17-2-vserver-amd64 (x86_64-linux-gnu-thread-multi)
    * PASS 854046 5.10.0 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * FAIL 853162 5.10.0 patch 32604 on Linux 2.4.20-8smp (i686-linux)
    * PASS 849808 5.10.0 on Linux 2.6.16.38 (i686-linux-thread-multi-64int-ld)
    * PASS 848334 5.8.8 on Linux 2.6.16.38 (i686-linux-thread-multi-64int-ld)
    * PASS 845943 5.10.0 on Solaris 2.10 (i86pc-solaris-thread-multi-64int)
    * PASS 844392 5.8.8 on Solaris 2.10 (i86pc-solaris-thread-multi-64int)
    * PASS 842830 5.10.0 patch 32468 on Solaris 2.9 (sun4-solaris-thread-multi)
    * PASS 842717 5.10.0 patch 31856 on Netbsd 2.1.0_stable (alpha-netbsd)
    * PASS 842191 5.8.8 on Openbsd 4.2 (OpenBSD.i386-openbsd-thread-multi-64int)
    * PASS 839805 5.10.0 on Solaris 2.11 (i386-pc-solaris2.11-thread-multi-64int)
    * PASS 839488 5.10.0 patch 32448 on Linux 2.4.27-3-686 (i686-linux-thread-multi)
    * PASS 838404 5.8.7 on Solaris 2.11 (i386-pc-solaris2.11-thread-multi)
    * PASS 836772 5.10.0 patch 32468 on Darwin 8.10.1 (darwin-thread-multi-2level)
    * PASS 836766 5.8.8 on Linux 2.4.27-3-686 (i686-linux)
    * PASS 836695 5.9.5 on Freebsd 6.2-release (i386-freebsd)
    * PASS 836424 5.6.2 on Linux 2.4.27-3-686 (i686-linux)
    * PASS 836318 5.10.0 on Linux 2.6.21.5-smp (i686-linux-thread-multi-64int-ld)
    * PASS 834217 5.8.8 on Linux 2.6.21.5-smp (i686-linux-thread-multi-64int-ld)
    * PASS 833854 5.8.8 on Linux 2.6.22-3-amd64 (i486-linux-gnu-thread-multi)
    * PASS 833532 5.10.0 on Linux 2.6.22-1-k7 (i686-linux)
    * FAIL 833507 5.6.2 on Freebsd 6.2-release (amd64-freebsd)
    * PASS 833211 5.8.8 on Freebsd 6.2-prerelease (amd64-freebsd)
    * PASS 833158 5.10.0 patch 32559 on Freebsd 6.2-release (amd64-freebsd)
    * PASS 833139 5.8.8 on Solaris 2.9 (sun4-solaris-thread-multi)
    * PASS 832795 5.8.8 on Solaris 2.9 (sun4-solaris-thread-multi)
    * PASS 832633 5.8.8 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832631 5.8.7 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832629 5.8.6 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832627 5.8.5 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832618 5.8.4 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832613 5.8.3 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832605 5.8.2 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832599 5.8.1 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * FAIL 832594 5.6.2 on Netbsd 3.1 (i386-netbsd-thread-multi-64int)
    * PASS 832231 5.10.0 on Linux 2.6.18-5-alpha-generic (alpha-linux-thread-multi)
    * FAIL 832124 5.10.0 on Linux 2.6.22-14-generic (i686-linux-thread-multi)
    * PASS 832117 5.8.8 on MSWin32 5.0 (MSWin32-x86-multi-thread)
    * PASS 831975 5.8.8 on MSWin32 5.1 (MSWin32-x86-multi-thread)
    * PASS 831965 5.8.8 on Cygwin 1.5.24(0.15642) (cygwin-thread-multi-64int)
    * FAIL 830858 5.6.2 on Linux 2.6.16-2-k7 (i686-linux-64int)
    * PASS 830850 5.8.5 on Linux 2.6.18-4-k7 (i686-linux-thread-multi-64int)
    * PASS 830846 5.8.6 on Linux 2.6.18-4-k7 (i686-linux-thread-multi-64int)
    * PASS 830843 5.8.7 on Linux 2.6.14 (i686-linux-thread-multi-64int)
    * PASS 830840 5.8.8 patch 32025 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 830838 5.9.5 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * FAIL 830834 5.10.0 on Linux 2.6.22-1-k7 (i686-linux-thread-multi)
    * FAIL 830833 5.10.0 on Linux 2.6.22-1-k7 (i686-linux)
