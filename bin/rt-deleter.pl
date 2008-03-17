
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
              autodelete  => [
                              qr/(?s:R+e+a+l+.+?m+e+n+!+.+?M+i+l+i+o+n+s+.+?o+f+.+?p+e+o+p+l+e+.+?a+c+r+o+s+.+?t+h+e+.+?w+o+r+l+d+)/,
                              qr/We strongly recommend deleting this letter and avoid clicking any links/,
                             ],
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
    $to = $sto unless $to =~ s/$x/$sto/; # s/// fails on 99..100
    push @tickets, $from..$to;
  } else {
    push @tickets, $rtickets[$i];
  }
}
@tickets = sort {$a <=> $b} @tickets;
print "Planning to visit tickets @tickets.\n";
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
  if ($ticket =~ /^(17751)$/) {
    # 
    warn "Alert: skipping known DOS ticket '$ticket'";
    next TICKET;
  }
  my $displ = "$Config{server}/Ticket/Display.html?id=$ticket";
  print "Retrieving ticket '$ticket' as $displ...\n";
  my $resp = $ua->get($displ);
  my $decoded = $resp->decoded_content;
  my $answer;
  if ($Config{nonono}) {
    print "not showing '$ticket'\n";
    sleep 1;
    $answer = "n";
  } elsif ($Config{autodelete}) {
  REGEXP: for my $rx (@{$Config{autodelete}}) {
      if ($decoded =~ $rx) {
        print "Ticket matches '$rx'\n";
        $answer = "y";
        last REGEXP;
      }
    }
  }
  my $text = _h2text($decoded);
  # http://rt.cpan.org/RT-Extension-QuickDelete/ToggleQuickDelete?id=32655
  if ($answer) {
    print (("=" x 79) . "\n") for 1,2;
    print "Answer '$answer' has already been determined automatically\n";
    sleep 1;
  } else {
    $DB::single++;
    open my $less, "|-", "less" or die "Could not fork: $!";
    binmode $less, ":utf8";
    print $less $text;
    close $less;
    print (("=" x 79) . "\n") for 1,2;
    $answer = prompt "You have now seen the ticket '$ticket'. Do you want to delete it? [Nyq]", "n";
  }
  if ($answer =~ /^q/i) {
    print "OK, end of loop\n";
    last TICKET;
  } elsif ($answer =~ /^n/i) {
    print "OK, leaving ticket '$ticket' alone\n";
    $ALL->{$ticket} ||= { text => $text,
                          want_delete => 0,
                          date => scalar(localtime),
                        };
    next TICKET;
  } elsif ($answer =~ /^y/i) {
    print "OK, trying to delete ticket '$ticket'\n";
    $ALL->{$ticket} = { text => $text,
                        want_delete => 1,
                        date => scalar(localtime),
                      };
    my $delete = "$Config{server}/RT-Extension-QuickDelete/ToggleQuickDelete?id=$ticket";
    my $resp = $ua->get($delete);
    if ($resp->is_success) {
      my $decoded = $resp->decoded_content;
      if ($decoded =~ /Undelete/) {
        $ALL->{$ticket}{could_delete} = 1;
        print "Ticket '$ticket' deleted\n";
      } else {
        my $text = _h2text($decoded);
        die "ALERT: response was succeess but did not contain 'Undelete'. text[$text]";
      }
    } else {
      $ALL->{$ticket}{could_delete} = 0;
      warn "ALERT: Could not delete ticket '$ticket': " . $resp->as_string;
      last TICKET;
    }
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
    last if $i >= 10;
  }
}

sub _h2text ($) {
  my($decoded) = @_;
  my $tree = HTML::TreeBuilder->new_from_content($decoded);
  my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
  my $text = $formatter->format($tree);
  $tree->delete;
  $text;
}
