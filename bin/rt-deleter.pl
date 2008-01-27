
# $HeadURL: /local/cpanpm/trunk/bin/query-rt-group-by-requestor.pl $

# see first posting http://use.perl.org/~LaPerla/journal/35252


=head1 rt-deleter

Get a cookie from, say firebug. Call me with numbers and ranges, eg

  23658..9 32665..72

Tickets will be displayed with 'less'.

The question will be aksed if you want to delete it.

=cut

use strict;
use warnings;

use ExtUtils::MakeMaker qw(prompt);
use Getopt::Long;
use HTML::TreeBuilder;
use HTML::FormatText;
use LWP::UserAgent ();
use YAML::Syck;
$YAML::Syck::ImplicitUnicode = 1;

my %Config = (
              server      => 'http://rt.cpan.org',
              username    => 'ANDK',
              password    => '',
              cookie      => '',
              less        => '',
             );

GetOptions(\my %config,
           (map { "$_=s" } keys %Config),
           "nonono!",
           "stats!",
          ) or die;
while (my($k,$v) = each %config) {
  $Config{$k} = $v;
}
unless ($Config{cookie}) {
  die "Missing mandatory option --cookie";
}
$ENV{LESS} = $Config{less};

my @rtickets = @ARGV or die "Usage: $0 [options] ticket...";
my @tickets;
for my $i (0..$#rtickets) {
  if ( $rtickets[$i] =~ /(\d+)\.\.(\d+)/ ) {
    my($from,$sto) = ($1,$2);
    my $to = $from;
    my $x = ("." x length($sto)) . '$';
    $to =~ s/$x/$sto/;
    push @tickets, $from..$to;
  } else {
    push @tickets, $rtickets[$i];
  }
}
{
  my $ans = prompt "Planning to visit tickets @tickets. OK? [Yn]", "y";
  unless ($ans =~ /^y/) {
    print "OK, exiting\n";
    exit;
  }
}
my $yaml_db_file = __FILE__;
$yaml_db_file =~ s/\.pl$/.yml/;
my $ALL;
if (-e $yaml_db_file) {
  $ALL = YAML::Syck::LoadFile($yaml_db_file);
} else {
  $ALL = {};
}

my $ua = LWP::UserAgent->new(
                             keep_alive => 1,
                            );
$ua->default_headers->push_header(
                                  Cookie => $config{cookie},
                                 );
$|=1;
TICKET: for my $ticket (@tickets) {
  unless ($ticket =~ /^\d+$/) {
    warn "Alert: skipping invalid ticket '$ticket'";
    next TICKET;
  }
  my $displ = "$Config{server}/Ticket/Display.html?id=$ticket";
  print "Retrieving ticket '$ticket' as $displ...\n";
  my $resp = $ua->get($displ);
  my $tree = HTML::TreeBuilder->new_from_content($resp->decoded_content);
  my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
  my $text = $formatter->format($tree);
  $DB::single++;
  if ($Config{nonono}) {
    print "not showing '$ticket'\n";
    sleep 1;
  } else {
    open my $less, "|-", "less" or die "Could not fork: $!";
    binmode $less, ":utf8";
    print $less $text;
    close $less;
  }
  $tree->delete;
  # http://rt.cpan.org/RT-Extension-QuickDelete/ToggleQuickDelete?id=32655
  my $answer;
  if ($Config{nonono}) {
    $answer = "n";
  } else {
    print (("=" x 79) . "\n") for 1,2;
    $answer = prompt "You have now seen the ticket '$ticket'. Do you want to delete it? [Nyq]", "n";
  }
  if ($answer =~ /^q/i) {
    last TICKET;
  } elsif ($answer =~ /^n/i) {
    $ALL->{$ticket} ||= { text => $text,
                          want_delete => 0,
                          date => scalar(localtime),
                        };
    next TICKET;
  } elsif ($answer =~ /^y/i) {
    $ALL->{$ticket} = { text => $text,
                        want_delete => 1,
                        date => scalar(localtime),
                      };
    my $delete = "$Config{server}/RT-Extension-QuickDelete/ToggleQuickDelete?id=$ticket";
    my $resp = $ua->get($delete);
    unless ($resp->is_success) {
      $ALL->{$ticket}{could_delete} = 0;
      warn "ALERT: Could not delete ticket '$ticket': " . $resp->as_string;
      last TICKET;
    }
    $ALL->{$ticket}{could_delete} = 1;
    print "Ticket '$ticket' deleted\n";
  }
}

open my $fh, ">:utf8", "$yaml_db_file.new" or die "Couldn't open: $!";
print $fh YAML::Syck::Dump($ALL);
rename $yaml_db_file, "$yaml_db_file~";
rename "$yaml_db_file.new", $yaml_db_file;
print "Memories written to $yaml_db_file\n";

if ($Config{stats}) {
  print "Collecting stats\n";
  my %del_by;
  for my $k (keys %$ALL) {
    if ($ALL->{$k}{text} =~ /^(.+) - Ticket deleted/m) {
      $del_by{$1}++;
    } elsif ($ALL->{$k}{could_delete}) {
      $del_by{ANDK}++;
    } else {
      $del_by{UNKNOWN}++;
    }
  }
  my $i = 0;
  for my $k (sort { $del_by{$b} <=> $del_by{$a} } keys %del_by) {
    $i++;
    printf "%3d %23s %5d\n", $i, $k, $del_by{$k};
    last if $i >= 40;
  }
}
