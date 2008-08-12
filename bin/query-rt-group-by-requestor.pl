
# $HeadURL$

# see first posting http://use.perl.org/~LaPerla/journal/35252

=pod

RT::Client::REST broke at some point in time and I posted a mostly
clueless patch that seemed to work. At least the progam did not die
immediately. The patch was integrated into 0.35 and soon after that
ticket 35146 was opened that reverted a part of my patch. (Sidenote:
The patch is posted reverse)

Now with that patch this program again died quickly with

    HTTP::Message content must be bytes

So I decided to patch REST thusly:

--- /home/k/.cpan/build/RT-Client-REST-0.35-d_Mo_f/lib/RT/Client/REST.pm	2008-04-15 12:24:11.000000000 +0200
+++ /home/src/perl/repoperls/installed-perls/perl/pVNtS9N/perl-5.8.0@32642/lib/site_perl/5.10.0/RT/Client/REST.pm	2008-05-01 09:27:13.000000000 +0200
@@ -496,7 +496,8 @@
         # not sufficiently portable and uncomplicated.)
         $res->code($1);
         $res->message($2);
-        $res->decoded_content($text);
+        use Encode;
+        $res->content(Encode::encode_utf8($text));
         #$session->update($res) if ($res->is_success || $res->code != 401);
         if ($res->header('set-cookie')) {
             my $jar = HTTP::Cookies->new;




Of course this cannot be correct but for me it works right now quite
well but only because rt.cpan.orgg sends charset=utf-8 or so.

=cut

use strict;
use warnings;

use RT::Client::REST;
use Getopt::Long;
use List::Util qw(max);
use YAML::Syck;

warn "Working with version $RT::Client::REST::VERSION";

my %Config = (
              server      => 'https://rt.cpan.org',
              username    => 'ANDK',
              password    => '',
              chunksize   => 396,
              nbsp        => 0,
              top         => 40,
             );

GetOptions(\my %config, map { "$_=s" } keys %Config);
while (my($k,$v) = each %config) {
  $Config{$k} = $v;
}

my $yaml_db_file = __FILE__;
$yaml_db_file =~ s/\.pl$/.yml/;
my $ALL;
if (-e $yaml_db_file) {
  $ALL = YAML::Syck::LoadFile($yaml_db_file);
} else {
  $ALL = {};
}
my $curmax = max keys %{$ALL->{tickets} || {}};
$curmax ||= 0;
print "highest registered ticket number ATM: $curmax\n";
$curmax ||= 1;
FINDHOLES: for (my $i = 1; $i <= $curmax; $i++) {
  if (exists $ALL->{tickets}{$i}) {
  } else {
    $curmax = $i;
    last FINDHOLES;
  }
}
print "Max after findholes: $curmax\n";
TRIM: for (my $i = $curmax;;$i--) {
    my $ticket = $ALL->{tickets}{$i};
    $curmax = $i;
    if (keys %$ticket) {
        last;
    } else {
        delete $ALL->{tickets}{$i};
    }
}
print "Max after trim: $curmax\n";

my $nextmax = $curmax + $Config{chunksize};

my $rt = RT::Client::REST->new(
                               server  => $Config{server},
                               timeout => 300
                              );

if ($Config{password}) {
  eval { $rt->login( username => $Config{username}, password => $Config{password} ); };
  die "Alert: Problem logging in: '$@'" if $@;

  my @ids;
  eval {
    @ids = $rt->search(
                       type    => 'ticket',
                       query   => qq[(Id >= $curmax and Id <= $nextmax)],
                      );
  };
  die "search failed: $@" if $@;

  my %ids;
  @ids{@ids} = ();
  $|=1;
  my $maxid = max @ids;
  print "filling $curmax..$maxid\n";
 ID: for my $id ($curmax..$maxid) {
    my $feedback;
    if ($ALL->{tickets}{$id}){
      $feedback = "E"; # existed before
    } else {
      if (exists $ids{$id}) {
      } elsif (keys %ids) {
      } else {
        print "\nStopping at $id.\n";
        last ID;
      }
      my $ticket = exists $ids{$id} ? $rt->show(type => 'ticket', id => $id) : {};
      if (keys %$ticket) {
        $feedback = "w"; # wrote something interesting
      } else {
        $DB::single++;
        $feedback = "e"; # empty
      }
      $ALL->{tickets}{$id} = $ticket;
    }
    print $feedback;
    delete $ids{$id};
    unless ($id % 17){
      print "z";
      sleep 3;
    }
  }
  YAML::Syck::DumpFile("$yaml_db_file.new", $ALL);
  rename "$yaml_db_file.new", $yaml_db_file;
  print "filled\n";
}

sub who {
  my($v) = @_;
  my $who = $v->{Requestors} || $v->{Creator};
  return "" unless $who;
  if ($who =~ s/\@cpan\.org(,.*)?$//) {
    $who = uc $who;
  }
  my %alias = (
               'ANDY@PETDANCE.COM, ESUMMERS' => 'PETDANCE',
               'Marek.Rouchal@gmx.net'      => 'MAREKR',
               'marek.rouchal@infineon.com' => 'MAREKR',
               'aaron@FreeBSD.org'          => 'ACDALTON',
               'agentzh@gmail.com'          => 'AGENT',
               'alexchorny@gmail.com'       => 'CHORNY',
               'andreas.koenig@anima.de'    => 'ANDK',
               'andy@petdance.com'          => 'PETDANCE',
               'a.r.ferreira@gmail.com'     => 'FERREIRA',
               'ask@develooper.com'         => 'ABH',
               'at@altlinux.org'            => 'ATOURBIN',
               'at@altlinux.ru'             => 'ATOURBIN',
               'audreyt@audreyt.org'        => 'AUDREYT',
               'autrijus@autrijus.org'      => 'AUDREYT',
               'barbie@missbarbell.co.uk'   => 'BARBIE',
               'blair@orcaware.com'         => 'BZAJAC',
               'chris@clotho.com'           => 'CLOTHO',
               'corion@corion.net'          => 'CORION',
               'cpan@ali.as'                => 'ADAMK',
               'cpan@audreyt.org'           => 'AUDREYT',
               'cpan@chrisdolan.net'        => 'CDOLAN',
               'cpan@clotho.com'            => 'CLOTHO',
               'cpan@pjedwards.co.uk'       => 'STIGPJE',
               'dan.horne@redbone.co.nz'    => 'DHORNE',
               'david@landgren.net'         => 'DLAND',
               'dha@panix.com'              => 'DHA',
               'gbarr@pobox.com'            => 'GBARR',
               'he@NetBSD.org'              => 'Havard Eidnes',
               'imacat@mail.imacat.idv.tw'  => 'IMACAT',
               'ivorw-cpan@xemaps.com'      => 'IVORW',
               'jdhedden@1979.usna.com'     => 'JDHEDDEN',
               'jesse@bestpractical.com'    => 'JESSE',
               'jesse@fsck.com'             => 'JESSE',
               'jhi@iki.fi'                 => 'JHI',
               'julian@mehnle.net'          => 'JMEHNLE',
               'mark@summersault.com'       => 'MARKSTOS',
               'mark@twoshortplanks.com'    => 'MARKF',
               'merlyn@stonehenge.com'      => 'MERLYN',
               'mnodine@alum.mit.edu'       => 'NODINE',
               'm.nooning@comcast.net'      => 'MNOONING',
               'mstevens@etla.org'          => 'MSTEVENS',
               'nadim@khemir.net'           => 'NKH',
               'nigel.metheringham@Dev.intechnology.co.uk' => 'NIGELM',
               'njh@bandsman.co.uk'         => 'NJH',
               'njh@ecs.soton.ac.uk'        => 'NJH',
               'nospam-abuse@bloodgate.com' => 'TELS',
               'ntyni@iki.fi'               => 'Niko Tyni',
               'nothingmuch@woobling.org'   => 'NUFFIN',
               'rafl@debian.org'            => 'FLORA',
               'rcaputo@pobox.com'          => 'RCAPUTO',
               'ron@savage.net.au'          => 'RSAVAGE',
               'rurban@x-ray.at'            => 'RURBAN',
               'shlomif@iglu.org.il'        => 'SHLOMIF',
               'schmorp@schmorp.de'         => 'MLEHMANN',
               'schwern@pobox.com'          => 'MSCHWERN',
               'schwern@bestpractical.com'  => 'MSCHWERN',
               'slaven@rezic.de'            => 'SREZIC',
               'slaven@cpan'                => 'SREZIC',
               'slaven.rezic@berlin.de'     => 'SREZIC',
               'steve.hay@uk.radan.com'     => 'SHAY',
               'steve@fisharerojo.org'      => 'SMPETERS',
               'steven@knowmad.com'         => 'WMCKEE',
               'stro@railways.dp.ua'        => 'STRO',
               'user42@zip.com.au',         => 'KRYDE',
               'ville.skytta@iki.fi'        => 'SCOP',
               'william@knowmad.com'        => 'WMCKEE',
               'xdaveg@gmail.com'           => 'DAGOLDEN',
              );
  $who = $alias{$who} || $who;
}

keys %{$ALL->{tickets}}; # reset iterator
my %S;
TICKET: while (my($k,$v) = each %{$ALL->{tickets}}) {
  my $who = who($v);
  next TICKET unless $who;
  $S{$who}++;
}
my $top = 1;
printf "<dl>\n";
for my $k (sort {$S{$b} <=> $S{$a}} keys %S) {
  my $x = sprintf "<code>%2d: %-9s %4d</code><br/>\n", $top, $k, $S{$k};
  $x =~ s/ /&nbsp;/g if $Config{nbsp};
  print $x;
  my $showtop = $config{top} || 40;
  last if $top >= $showtop;
  $top++;
}
printf "</dl>\n";

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
