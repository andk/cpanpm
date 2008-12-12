#!/usr/bin/perl

=pod

customization and extension of mytail-f.pl for megainstall log files.

with the ability to switch to the next file when one file is finished;

displaying filename and current package from time to time;

intelligent handling of incomplete lines

=cut

use File::Basename qw(basename);
use File::Spec;
use Getopt::Long;
use List::Util qw(maxstr);
use Time::HiRes qw(time sleep);

our %Opt;
GetOptions(\%Opt,
          "debug!",
          ) or die;

my $curpos = 0;
my $line;
my $file = youngest();
my $currentpackage;
$| = 1;

our @sleepscala = (2,3,5,8,13,21,34);
@sleepscala = (2,3,5) if $Opt{debug};
my $sleepscalaindex = 0;
FILE: while () {
    open GWFILE, $file or die "Could not open '$file': $!";
    my $lines = 0;
    while (<GWFILE>) {
        $lines++;
    }
    close GWFILE;
    my $i = 0;
    open GWFILE, $file or die "Could not open '$file': $!";
    my $lastline = "";
  LINE: for (;;) {
        warn "lines[$lines]" if $Opt{debug};
        my $gotone;
        for ($curpos = tell(GWFILE); $line = <GWFILE>; $curpos = tell(GWFILE)) {
            $i++;
            # warn "i[$i]curpos[$curpos]" if $Opt{debug};
            $gotone=1;
            if ($line =~ /^\s+CPAN\.pm:/) {
                ($currentpackage) = $line =~ /^\s+CPAN\.pm: Going to build\s+(\w[^\e]+\w)(?:\e.*)\s*$/;
            }
            if ($i > $lines - 10) {
                my @time = localtime;
                my $localtime = sprintf "%02d:%02d:%02d", @time[2,1,0];
                my $fractime = time;
                $fractime =~ s/\d+\.//;
                $fractime .= "0000";
                my $prefix = sprintf "%5d %s.%s", $i, $localtime, substr($fractime,0,4);
                if (($i % 18) == 0) {
                    my $filelabel = $file;
                    my $currentpackagelabel;
                    if ($currentpackage) {
                        $currentpackagelabel = $currentpackage;
                        $currentpackagelabel .= " "
                            while length $currentpackagelabel < length $filelabel;
                        $filelabel .= " "
                            while length $currentpackagelabel > length $filelabel;
                    }
                    if (length $lastline) {
                        print "\n(( $filelabel ))\n";
                    } else {
                        print "(( $filelabel ))\n";
                    }
                    if ($currentpackagelabel) {
                        print "(( $currentpackagelabel ))\n";
                    }
                    if ($lastline) {
                        print $lastline;
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
        if ($gotone) {
            sleep 0.33;
            $sleepscalaindex=0;
        } elsif ($i < $lines) {
            # no sleep
        } else {
            sleep $sleepscala[$sleepscalaindex];
            my $youngest = youngest();
            if ($sleepscalaindex<$#sleepscala) {
                $sleepscalaindex++;
                if ($sleepscalaindex==$#sleepscala) {
                    printf "\nINFO: max sleepscala reached at %s\n", scalar localtime;
                }
            } else {
                printf "\rINFO: %s youngest[%s]", scalar localtime, basename $youngest;
            }
            if ($youngest ne $file) {
                print "\nswitching to $youngest\n";
                $file = $youngest;
                next FILE;
            }
        }
        seek(GWFILE, $curpos, 0);  # seek to where we had been
    }
}

sub youngest {
    my($dir,$pat) = @_;
    $dir ||= "/home/sand/cpanpm/logs/";
    $pat ||= qr/^megainstall\..*\.out$/;
    opendir my $dh, $dir or die "Could not opendir '$dir': $!";
    my $youngest = maxstr grep { $_ =~ $pat } readdir $dh;
    File::Spec->catfile($dir,$youngest);
}
