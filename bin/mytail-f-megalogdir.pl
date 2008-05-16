#!/usr/bin/perl

=pod

extended version of mytail-f.pl with the ability to switch to the next file

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
    for (;;) {
        for ($curpos = tell(GWFILE); $line = <GWFILE>; $curpos = tell(GWFILE)) {
            if (++$i > $lines - 10) {
                my @time = localtime;
                my $localtime = sprintf "%02d:%02d:%02d", @time[2,1,0];
                my $fractime = time;
                $fractime =~ s/\d+\.//;
                $fractime .= "0000";
                if (($i % 23) == 0) {
                    print "\n(($file))\n";
                }
                printf "%5d %s.%s %s", $i, $localtime, substr($fractime,0,4), $line;
            }
        }
        sleep 0.33;
        seek(GWFILE, $curpos, 0);  # seek to where we had been
        my $youngest = youngest();
        if ($youngest ne $file) {
            $file = $youngest;
            next FILE;
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
