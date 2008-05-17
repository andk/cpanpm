#!/usr/bin/perl

=pod

customization and extension of mytail-f.pl with the ability to switch
to the next file

Bug: if we stand in the middle of a line, we really disturb the
output. FIXED

Bug II: we're probably reading too often the directory. we chould skip
that when we just found some output.

Bug III: we should repeat the current package from the last CPAN.pm:
line.

=cut

use File::Spec;
use List::Util qw(maxstr);
use Time::HiRes qw(time sleep);


my $curpos = 0;
my $line;
my $file = youngest();

FILE: while () {
    open GWFILE, $file or die "Could not open '$file': $!";
    my $lines;
    while (<GWFILE>) {
        $lines = $.;
    }
    close GWFILE;
    my $i = 0;
    open GWFILE, $file or die "Could not open '$file': $!";
    my $lastline = "";
    for (;;) {
        my $gotone;
        for ($curpos = tell(GWFILE); $line = <GWFILE>; $curpos = tell(GWFILE)) {
            $i++;
            $gotone=1;
            if ($i > $lines - 10) {
                my @time = localtime;
                my $localtime = sprintf "%02d:%02d:%02d", @time[2,1,0];
                my $fractime = time;
                $fractime =~ s/\d+\.//;
                $fractime .= "0000";
                my $prefix = sprintf "%5d %s.%s", $i, $localtime, substr($fractime,0,4);
                if (($i % 13) == 0) {
                    if (length $lastline) {
                        print "\n(($file))\n";
                        print $lastline;
                    } else {
                        print "(($file))\n";
                    }
                }
                if (length $lastline) {
                    printf "\n%s %s%s", $prefix, $lastline, $line;
                } else {
                    printf "%s %s", $prefix, $line;
                }
                if ($line =~ /\n/) {
                    $lastline = "";
                } else {
                    $i--;
                    $lastline = $line;
                }
            }
        }
        sleep 0.33;
        seek(GWFILE, $curpos, 0);  # seek to where we had been
        unless ($gotone) {
            my $youngest = youngest();
            if ($youngest ne $file) {
                $file = $youngest;
                next FILE;
            }
        }
    }
}

sub youngest {
    my($dir,$pat) = @_;
    $dir ||= "/home/sand/CPAN-SVN/logs/";
    $pat ||= qr/^megainstall\..*\.out$/;
    opendir my $dh, $dir or die "Could not opendir '$dir': $!";
    my $youngest = maxstr grep { $_ =~ $pat } readdir $dh;
    File::Spec->catfile($dir,$youngest);
}
