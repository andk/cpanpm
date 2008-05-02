use strict;
use warnings;

use CPAN;
use DateTime;
use Getopt::Long;
use Time::Progress;

our %Opt;
GetOptions(\%Opt,
           "fulldate!",
           "n=n",
           "withcpan!",
           ) or die "Usage: ...";

$Opt{n} ||= 40;
my $ROOT = "/home/ftp/pub/PAUSE";
open my $fh, "zcat $ROOT/modules/02packages.details.txt.gz|" or die;
my(%age,%distro);
my $state = "header";
my $current_line = 0;
my $tp = Time::Progress->new();
my $lines;
$| = 1;
while (<$fh>) {
    if ($state eq "header") {
        if (/^\s*$/){
            $state = "body";
            next;
        } elsif (/^Line-Count:\s*(\d+)/) {
            $lines = $1;
            $tp->attr( min => 1, max => $lines );
        }
    } elsif ($state eq "body") {
        chomp;
        $current_line++;
        my($m,$v,$d) = split " ", $_;
        unless (-e "$ROOT/authors/id/$d"){
            warn "could not find '$d' for '$m'";
            next;
        }
        my $age = -M _;
        $age{$m} = $age;
        $distro{$m} = $d;
        if ($lines==$current_line || !($current_line % 100)) {
            my $formatted_current_line = sprintf "%8d", $current_line;
            print $tp->report("\r$formatted_current_line %p over: %l s, left %e s; ETA: %f", $current_line );
        }
    } else {
        die "illegal state $state";
    }
}
print "\n";
my @m = sort { $age{$a} <=> $age{$b} } keys %age;
my $painted = 0;
if ($Opt{withcpan}) {
    CPAN::Index->reload;
}
my $now = DateTime->now;
my $value_sets = [];
my @t_index;
for my $i (0..$#m) {
    while (($painted/$Opt{n}) < ($i/@m)) {
        my $age = $age{$m[$i]};
        my $mtime = $^T-86400*$age;
        my $dt = DateTime->from_epoch(epoch => $mtime);
        my $lt = $dt->ymd;
        my $age_days = int(($now->epoch - $dt->epoch)/86400);
        my $have = "";
        my $have_format = "%s";
        my $display_date = $age_days;
        my $date_format = "%4d";
        if ($Opt{withcpan}) {
            $have_format = " %-5s";
            my $mod = CPAN::Shell->expand("Module",$m[$i]);
            $have = CPAN::Shell->expand("Module",$m[$i])->inst_version if $mod;
            $have = "" unless defined $have;
        }
        if ($Opt{fulldate}) {
            $date_format = "%-10s";
            $display_date = $lt;
        }
        if ($painted>1 && (($painted % ($Opt{n}/4)) == ($Opt{n}/4-1))) {
            push @t_index, $painted;
        }
        $painted++;
        printf "%2d $date_format$have_format %-20s %s\n", $painted, $display_date, $have, $m[$i], substr($distro{$m[$i]},5);
        push @{$value_sets->[0]}, -$display_date;
        push @{$value_sets->[1]}, 1-(($painted-1)/$Opt{n});
    }
}
unless (@t_index == 3) {
    warn "ALERT: not 3 elements in t_index[@t_index]";
}
XAXIS: push @{$value_sets->[0]}, $value_sets->[0][-1]; # must use the 0 for proper scaling
YAXIS: push @{$value_sets->[1]}, 0;
my @txlabel = map { sprintf "%dd", -$_ } @{$value_sets->[0]}[@t_index];
# good enough results with n=20
# todo: right axis, labels 75,50,25 and the 3 corresponding dates
{
    use Google::Chart;
    use List::Util qw(min max);
    for my $vs (@$value_sets) {
        my $min = min @$vs;
        my $max = max @$vs;
        my $range = $max - $min;
        $vs = [ map { int(100 * ($_ - $min)/$range) } @$vs ];
    }
    my @txpos = @{$value_sets->[0]}[@t_index];

    my $chart = Google::Chart->new(
                                   type_name => 'type_line_xy',
                                   set_size  => [ 300, 120 ],
                                   data_spec => {
                                                 encoding  => 'data_simple_encoding',
                                                 max_value => 100,
                                                 value_sets => $value_sets,
                                                },
                                  );
    print $chart->get_url, "&chxt=x,r&chxl=0:|$txlabel[0]|$txlabel[1]|$txlabel[2]|1:|0|25|50|75|100&chxp=0,$txpos[0],$txpos[1],$txpos[2]&chm=c,FF0000,0,$t_index[0],10|c,FF0000,0,$t_index[1],10|c,FF0000,0,$t_index[2],10&chf=c,ls,90,999999,0.25,AAAAAA,0.25,CCCCCC,0.25,EEEEEE,0.25\n";
}

=pod

Calculate percentiles, well 1/40-tiles, of all modules. Funny that all
quartiles today are pretty close to newyear. This was the output:

Found 53394 modules
 1 Thu Apr 10 20:15:53 2008            Test::A8N::File
 2 Sun Apr  6 15:21:12 2008            WebService::ISBNDB::Iterator
 3 Sat Mar 29 17:29:52 2008            VS::Chart::Color
 4 Sun Mar 23 00:35:16 2008            Module::ScanDeps::DataFeed
 5 Tue Mar 11 18:32:08 2008            Curses::UI::Popupmenu
 6 Sat Mar  1 00:15:57 2008            Paranoid
 7 Mon Feb 18 16:58:22 2008            Config::IniHash
 8 Mon Feb  4 15:46:18 2008            Geo::Proj::Japan
 9 Tue Jan 22 08:31:13 2008            Spreadsheet::Engine::Function::WEEKDAY
10 Thu Jan  3 17:55:37 2008            SystemC::Vregs::Language
11 Sat Dec 15 20:10:17 2007            Ogre::SceneManager
12 Thu Nov 22 19:12:58 2007            Alzabo::Create
13 Sat Oct 27 21:35:43 2007            KinoSearch::Search::HitQueue
14 Thu Sep 27 22:42:46 2007            Business::PayPal::API::CaptureRequest
15 Sun Aug 26 01:19:30 2007            Wx::DemoModules::wxStaticText
16 Sat Jul 28 20:52:11 2007            CommandParser::Vcs
17 Fri Jun  8 16:31:15 2007            HTML::FromMail::Page
18 Thu Apr 19 03:44:27 2007            Chemistry::OpenBabel
19 Sat Mar 17 23:17:11 2007            Java::JCR::Version::VersionHistory
20 Sun Jan 21 01:42:01 2007            Authen::Passphrase::Clear
21 Mon Nov 27 20:40:52 2006            CQL::PrefixNode
22 Fri Sep 22 05:50:59 2006            Template::Magic::Zone
23 Tue Jul  4 23:41:45 2006            Time::TCB
24 Fri May 12 14:49:12 2006            Test::Unit::GTestRunner
25 Tue Feb 28 00:42:21 2006            DBIx::Class::Loader::Generic
26 Thu Dec  1 17:55:02 2005            IO::Handle::Rewind
27 Sun Sep  4 02:39:20 2005            Games::Sudoku::OO::Set
28 Wed Jun  1 23:31:26 2005            Parse::EBNF::Token
29 Mon Feb 28 05:23:57 2005            Class::StrongSingleton
30 Tue Nov 30 11:40:10 2004            CGI::Wiki::Formatter::UseMod
31 Thu Aug 12 22:14:32 2004            DBomb::Meta::OneToMany
32 Tue Apr 20 20:57:27 2004            Apache::AuthenNIS
33 Tue Dec 23 10:47:30 2003            Bio::Tools::Run::PiseApplication::descseq
34 Tue Oct  7 14:00:51 2003            Apache::Profiler
35 Mon Jun 30 15:52:49 2003            WWW::BookBot::Test
36 Sun Jan 19 16:04:55 2003            Introspector::MetaInheritance
37 Fri Sep 20 14:35:14 2002            Anarres::Mud::Driver::Efun::MudOS
38 Sun Feb 10 06:55:51 2002            Math::MVPoly::Monomial
39 Tue Apr 17 13:41:26 2001            CGI::Test::Form::Widget::Menu::List
40 Mon Dec 20 00:05:25 1999            Wizard::LDAP::User

Quartile 1 about newyear 2008, quartile 2 January 2007, quartile 3
November 2004.

=cut
