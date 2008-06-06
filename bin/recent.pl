#!/usr/bin/perl

=head1 NAME

recent - 

=head1 SYNOPSIS

 watch -n 20 'perl ~k/sources/CPAN/GIT/trunk/bin/recent.pl -n 15;perl -e\$c=800\;while\(--\$c\){print\ rand\(80\)\<1\?\"_\":\"\ \"} '

=head1 DESCRIPTION

Show most recent uploads according to the RECENT file and mark the
currently processing one (according to ~/.cpan/loop-over-recent.state
with a star.

=cut

use CPAN::DistnameInfo;
use Getopt::Long;
use YAML::Syck;

our %Opt;
GetOptions(\%Opt,
          "n=i",
          );
use lib "/home/k/dproj/PAUSE/wc/lib/";
use PAUSE; # loads File::Rsync::Mirror::Recentfile for now

my $statefile = "$ENV{HOME}/.cpan/loop-over-recent.state";
my $max_epoch_worked_on = 0;

my $rx = qr!\.(tar.gz|tar.bz2|zip|tgz|tbz)$!; # see also loop-over...

if (-e $statefile) {
  local $/;
  my $state = do { open my $fh, $statefile or die "Couldn't open '$statefile': $!";
                   <$fh>;
                 };
  chomp $state;
  $state += 0;
  $max_epoch_worked_on = $state if $state;
}
my $rf = File::Rsync::Mirror::Recentfile->new(
                                              canonize => "naive_path_normalize",
                                              localroot => "/home/ftp/pub/PAUSE/authors/id/",
                                              intervals => [qw(2d)],
                                             );

my $recent_events = $rf->recent_events;
{
  my %seen;
  $recent_events = [ grep { my $d = CPAN::DistnameInfo->new($_->{path});
                            !$seen{$d->dist}++
                                && $_->{path} =~ $rx
                                    && $_->{type} eq "new";
                            
                          } @$recent_events ];
}
my $current_is_marked = 0;
my $count = 0;
ITEM: for my $i (0..$#$recent_events) {
  my $item = $recent_events->[$i];
  my $mark = "";
  if (!$current_is_marked) {
    if ($max_epoch_worked_on) {
      if ($max_epoch_worked_on == $item->{epoch}) {
        $mark = "*";
        $current_is_marked = 1;
      } elsif ($max_epoch_worked_on < $item->{epoch}
               && $#$recent_events > $i
               && $max_epoch_worked_on > $recent_events->[$i+1]->{epoch}) {
        printf "%1s %s\n", "*", scalar localtime $recent_events->[$i+1]->{epoch};
        $current_is_marked = 1;
      }
    }
  }
  printf "%1s %s %s\n", $mark, scalar localtime $item->{epoch}, substr($item->{path},5);
  if ($Opt{n} && ++$count>=$Opt{n}) {
    last ITEM;
  }
}

__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
