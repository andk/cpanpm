use strict;
use warnings;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
# my @want_config = qw();
my @want_config = qw(byteorder libc gccversion intsize use64bitint archname optimize);
while (<DATA>) {
    my($ok,$id) = /(PASS|FAIL)\s+(\d+)/ or next;
    my $target = "nntp-testers/$id";
    unless (-e $target) {
        $ua->mirror("http://www.nntp.perl.org/group/perl.cpan.testers/$id",$target);
    }
    open my $fh, $target or die;
    my(%extract);
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
    }
    my $diag = "";
    for my $want (@want_config) {
        my $have  = $extract{$want} || "[UNDEF]";
        $diag .= "$want\[$have]";
    }
    print "ok[$ok]id[$id]$diag\n";
}
__END__
Crypt-CipherSaber 1.00 (14 FAILs, 34 PASSes)

    * PASS 1121892 5.11.0 patch 33450 on Linux 2.6.22-1-k7 (i686-linux-thread-multi)
    * FAIL 1120668 5.10.0 on Freebsd 6.2-release (amd64-freebsd)
    * FAIL 1120408 5.10.0 on Freebsd 6.2-release (amd64-freebsd-thread-multi)
    * PASS 1120359 5.8.8 on Freebsd 6.2-prerelease (amd64-freebsd)
    * PASS 1120357 5.10.0 on Freebsd 6.2-release (amd64-freebsd)
    * PASS 1120351 5.10.0 on Freebsd 6.2-release (amd64-freebsd-thread-multi)
    * PASS 1120347 5.6.2 on Freebsd 6.2-release (amd64-freebsd)
    * PASS 1120315 5.8.8 on Linux 2.6.14 (i686-linux-64int)
    * FAIL 1116844 5.10.0 patch 33443 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 1114378 5.8.8 patch 33436 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 1109225 5.10.0 patch 33412 on Linux 2.6.22-1-k7 (i686-linux-thread-multi-64int)
    * PASS 1104563 5.8.8 patch 33430 on Linux 2.6.22-1-k7 (i686-linux-thread-multi)
    * PASS 1102125 5.11.0 patch 33423 on Linux 2.6.22-1-k7 (i686-linux)
    * FAIL 1086582 5.11.0 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 1031510 5.8.8 patch 33243 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 979087 5.8.8 patch 33008 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 961849 5.10.0 on Linux 2.6.23.1-slh64-smp-32 (x86_64-linux)
    * PASS 895351 5.11.0 on Linux 2.6.22-1-k7 (i686-linux-thread-multi-64int)
    * PASS 881249 5.11.0 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 877086 5.11.0 on Linux 2.6.22-1-k7 (i686-linux)
    * FAIL 862529 5.10.0 patch 32468 on Solaris 2.9 (sun4-solaris-thread-multi)
    * FAIL 843202 5.10.0 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 822953 5.10.0 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 766430 5.9.5 on Netbsd 2.1.0_stable (alpha-netbsd)
    * PASS 760318 5.8.8 patch 32273 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * FAIL 716030 5.10.0 on Linux 2.6.22-1-k7 (i686-linux-thread-multi-64int)
    * FAIL 714784 5.10.0 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 713181 5.10.0 on Linux 2.6.22-1-k7 (i686-linux-thread-multi-64int)
    * PASS 706776 5.10.0 on Linux 2.6.22-1-k7 (i686-linux-thread-multi)
    * PASS 673375 5.8.8 patch 32025 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 665248 5.10.0 on Linux 2.6.22-1-k7 (i686-linux)
    * PASS 616030 5.9.5 on Freebsd 6.2-release (i386-freebsd)
    * PASS 614980 5.10.0 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * FAIL 591217 5.9.5 on Linux 2.6.22-1-k7 (i686-linux-64int)
    * PASS 581974 5.6.2 on Linux 2.4.27-3-686 (i686-linux)
    * PASS 580916 5.9.5 on Darwin 8.10.1 (darwin-2level)
    * PASS 551698 5.9.5 on Cygwin 1.5.24(0.15642) (cygwin)
    * PASS 537920 5.6.2 on Linux 2.6.16-2-k7 (i686-linux-64int)
    * FAIL 485045 5.9.5 on Linux 2.6.18-4-k7 (i686-linux-64int)
    * PASS 475541 5.9.5 on Linux 2.6.18-4-k7 (i686-linux-64int)
    * PASS 335463 5.8.8 on Linux 2.6.16.14 (x86_64-linux-thread-multi-ld)
    * PASS 329933 5.8.8 on Linux 2.6.16.14 (x86_64-linux-thread-multi-ld)
    * FAIL 306652 5.8.6 on Linux 2.6.9-34.elsmp (i386-linux-thread-multi)
    * FAIL 224455 5.8.7 on Linux 2.4.30 (i686-linux-thread-multi-64int-ld)
    * FAIL 224431 5.8.6 on Cygwin 1.5.12(0.11642) (cygwin-thread-multi-64int)
    * FAIL 224193 5.8.5 on MSWin32 4.0 (MSWin32-x86-multi-thread)
    * PASS 224070 5.8.5 on Linux 2.4.19-44mdkenterprise (i386-linux-thread-multi)
    * PASS 223905 5.8.5 on Solaris 2.9 (sun4-solaris-thread-multi)
