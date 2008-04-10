use strict;
use warnings;

my $ROOT = "/home/ftp/pub/PAUSE";
open my $fh, "zcat $ROOT/modules/02packages.details.txt.gz|" or die;
my(%age,%distro);
while (<$fh>) {
    next if 1../^\s*$/;
    chomp;
    my($m,$v,$d) = split " ", $_;
    warn "could not find '$d' for '$m'" unless -e "$ROOT/authors/id/$d";
    my $age = -M _;
    $age{$m} = $age;
    $distro{$m} = $d;
}
my @m = sort { $age{$a} <=> $age{$b} } keys %age;
warn sprintf "Found %d modules\n", scalar @m;
my $painted = 0;
for my $i (0..$#m) {
    while (($painted/40) < ($i/@m)) {
        my $age = $age{$m[$i]};
        my $mtime = $^T-86400*$age;
        my $lt = localtime($mtime);
        printf "%2d %-35s %s\n", ++$painted, $lt, $m[$i];
    }
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
