#!/usr/bin/perl -w -*- mode: cperl -*-
use strict;
BEGIN {$CPAN::Config_loaded=1}
BEGIN {$CPAN::Config_loaded=1} # keep old perls with -w quiet
use ExtUtils::MakeMaker qw(:DEFAULT);
use File::Path;
eval { require File::Spec; };
my $HAVE_FILE_SPEC = !$@;
eval { require YAML::Syck; };
my $HAVE_YAML_SYCK = !$@;
use File::Basename qw(basename);
require Config;
my $HAVE_MAKE = basename($Config::Config{make}) eq "make"; # file-scoped!
use vars qw($VERSION);
use vars qw(@DD_PREFS @ST_PREFS);

@DD_PREFS = qw(
               distroprefs/GBARR.libnet
               distroprefs/ILYAZ.Term-ReadLine-Perl
               distroprefs/INGY.YAML
               distroprefs/RGIERSIG.Expect
               distroprefs/ABW.Template-Toolkit
               lib/CPAN/Kwalify/distroprefs
              );

@ST_PREFS = qw(
              );


my $Id = q$Id: Makefile.PL 146 2005-08-09 04:25:21Z k $;
$VERSION = sprintf "%.3f", 1 + substr(q$Rev: 146 $,4)/1000;

my $version_diff = 0; # we'll have to die if this becomes true
my $version_from;
{
  local $^W;
  $ExtUtils::MakeMaker::VERSION = eval $ExtUtils::MakeMaker::VERSION;
  warn "Your MakeMaker is a bit dated[$ExtUtils::MakeMaker::VERSION].\nYou should get a new one\n"
        if $ExtUtils::MakeMaker::VERSION < 6.0;
}
our $SVN_RELEASE = 0;
if (-d ".svn") {
  $SVN_RELEASE = 1;
} elsif ($ARGV[0] && $ARGV[0] =~ /setversion/) {
  warn "!!!making SVK based release, take care!!!";
  @ARGV = ();
  sleep 2;
}
if ($HAVE_FILE_SPEC) {
  $version_from = File::Spec->catfile(qw(lib CPAN.pm));
  my $version_set_manually = 1; # not by SVN

  if ($ARGV[0] && $ARGV[0] eq "--setversion") {
    die "Your perl is a bit dated[$]].\nDo not make a release with it\n" if $] < 5.008;
    die "Your MakeMaker is a bit dated[$ExtUtils::MakeMaker::VERSION].\nDo not make a release with it\n"
        if $ExtUtils::MakeMaker::VERSION < 6.3004;
    die "Your MakeMaker doesn't do the sign woodoo" unless
        MM->can("signature_target");
    shift @ARGV;
    my $st;
    open $st, "svn st -u|" or die;
    my $dirty = 0;
    while (<$st>) {
      next if /^\?/;
      next if /^Head revision:/;
      next if /^Status against revision:/;
      print;
      $dirty++;
    }
    close $st;
    die "Not everything checked in or out?" if $dirty;

    # $re parses the upper boundary of the output of svnversion
    my $re;
    eval q{ $re = qr/(?:\d+:)?(\d+)[SM]*$/; };
    die $@ if $@; # old perl
    my($sv_dot)  = `svnversion .`             =~ $re;
    my($sv_from) = `svn st -u -v $version_from`  =~ /^.{8}\s*(?:\d+)\s*(\d+)/;
    die "Could not determine sv_from or sv_dot"
        unless $sv_from > 0 && $sv_dot > 0;
    if ($version_set_manually) {
      # we must control that the VERSION in CPAN.pm is the same as in the Makefile
      unshift @INC, "lib";
      require $version_from;
      open my $fh, "make the-release-name|" or die;
      my $have_version;
      while (<$fh>) {
        next unless /^version\s+([\d\._]+)/;
        $have_version = eval $1;
      }
      die "could not determine current version from Makefile" unless $have_version;
      eval q{
      no warnings "numeric";
      if ($CPAN::VERSION != $have_version) {
        warn "Not equal: CPAN::VERSION[$CPAN::VERSION] Makefile version[$have_version]";
        $version_diff = 1;
      }
};
      die $@ if $@;
    } else {
      if ($sv_dot > $sv_from) {
        warn "setting some property to make a checkin of this file possible";
        0==system(svn => "propset",
                  "cpan:release",
                  "after_$sv_dot",
                  $version_from) or die;
        warn "checking in to get the version up to the bleading edge";
        0==system(svn => "ci",
                  "-m",
                  "Property set for release after_$sv_dot",
                  $version_from) or die;
        # will have to die after Makefile is rewritten:
        $version_diff = 1;
      }
    }
    exit unless $version_diff;
  }
}

# for 5.004_05 I installed all of them manually despite errors;
# version hints as of 2006-02
my $prereq_pm = {
                 'File::Spec' => 0,   # KWILLIAMS; requires
                                      # Scalar::Util;
                                      # PathTools-3.16.tar.gz
                 'File::Temp' => 0,   # JTENNESS; requires Test::More;
                 'Scalar::Util' => 0, # GBARR;
                                      # Scalar-List-Utils-1.18.tar.gz;
                 'Test::Harness' => 2.62,
                 'Test::More' => 0,   # MSCHWERN;
                                      # Test-Simple-0.62.tar.gz;
                };

if ($HAVE_FILE_SPEC) {
  # import PAUSE public key to user's keychain
  require Config;
  my $dir;
  for $dir (split /$Config::Config{path_sep}/, $ENV{PATH}) {
    my $abs = File::Spec->catfile($dir, 'gpg');
    my $cmd;
    if ($cmd = MM->maybe_command($abs)) {
      print "Importing PAUSE public key into your GnuPG keychain... ";
      system($cmd, '--quiet', '--import', <PAUSE*.pub>);
      print "done!\n";
      print "(You may wish to trust it locally with 'gpg --lsign-key 450F89EC')\n";
      last;
    }
  }
}

my @sign = (MM->can("signature_target") ? (SIGN => 1) : ());
# warn "sign[@sign]";
WriteMakefile(
              INSTALLDIRS  => 'perl',  # as it is coming with perl
              NAME         => 'CPAN',
              VERSION_FROM => $version_from,
              EXE_FILES    => [qw(scripts/cpan)],
              PREREQ_PM    => $prereq_pm,
              ($ExtUtils::MakeMaker::VERSION >= 6.3002 ?
               (LICENSE      => "perl") : (),
              ),
              clean        => {
                               FILES => "lib/CPAN/Config.pm t/dot-cpan/FTPstats.yml",
                              },
              @sign,
              ($] >= 5.005 ?
               (
                ABSTRACT_FROM  => 'lib/CPAN.pm', # retrieve abstract from module
                AUTHOR         => 'Andreas Koenig <andreas.koenig.gmwojprw@franz.ak.mind.de>') : (),
              ),
              dist => {
                       DIST_DEFAULT => join(" ", # note: order matters!
                                            "verify-no-subdir",
                                            "dd-prefs",
                                            "Makefile",
                                            "no_CR",
                                            "META.yml",
                                            "setversion",
                                            "README",
                                            "testdistros",
                                            "all",
                                            "chlog",
                                            "tardist",
                                           ),
                       COMPRESS => 'gzip -9',
                      },
             );

if ($version_diff){
  die "
==> I had to update some \$VERSIONs <==
==> Your Makefile has been rebuilt. <==
==> Please rerun the make command.  <==
";
}

package MY;

sub macro {
    q{
LC_ALL_noexport=en_GB.utf8

ALL_PERLS = /usr/bin/perl \
	    /usr/local/bin/perl \
            /usr/local/perl-5.004_05/bin/perl \
            /usr/local/perl-5.005_04/bin/perl \
            /usr/local/perl-5.6.2/bin/perl \
	    /usr/local/perl-5.8.0/bin/perl \
	    /usr/local/perl-5.8.4/bin/perl \


# not sorted because order matters
MEGA_BASE = \
 Bundle::CPANxxl \
 CPAN::DistnameInfo \
 DBD::SQLite \
 /home/src/perl/tk/SVN/. \
 /home/src/perl/cpan-sql-stuff/CPAN-SQLite/. \


MEGA_INSTALL = \
 ANDK/keepcool-0.344 \
 Algorithm::Annotate \
 Algorithm::C3 \
 Algorithm::Partition \
 Algorithm::Permute \
 AltaVista::BabelFish \
 Alzabo \
 App::Ack \
 App::CLI \
 Array::Iterator \
 Authen::Simple \
 AxKit \
 B::Deobfuscate \
 BFD \
 Bit::Vector::Minimal \
 Bundle::Pause \
 Bundle::Perl6 \
 Bundle::Phalanx100 \
 Bundle::RT \
 Bundle::Slash \
 Business::CreditCard \
 Business::OnlinePayment \
 CDB_File \
 CGI::Ajax \
 CGI::Application \
 CGI::Application::Plugin::AutoRunmode \
 CGI::Application::Plugin::DevPopup \
 CGI::Application::Plugin::Forward \
 CGI::Session \
 CGI::Untaint \
 CPAN::Unwind \
 CPAN::YACSmoke \
 CSS \
 CSS::SAC \
 Cache::FastMmap \
 Cache::File \
 Cache::Memcached \
 Cache::Memcached::XS \
 Cache::Simple::TimedExpiry \
 Cairo \
 Carp::Always \
 Carp::Assert::More \
 Catalyst \
 Catalyst::Action::RenderView \
 Catalyst::Devel \
 Catalyst::Manual \
 Catalyst::Plugin::Authentication \
 Catalyst::Plugin::Authorization::Roles \
 Catalyst::Plugin::ConfigLoader \
 Catalyst::Plugin::FormValidator \
 Catalyst::Plugin::Session \
 Catalyst::Plugin::Static::Simple \
 Catalyst::View::TT \
 Chatbot::Eliza \
 Class::AutoClass \
 Class::Base \
 Class::C3 \
 Class::DBI::AbstractSearch \
 Class::DBI::AsForm \
 Class::DBI::Pager \
 Class::DBI::Plugin::Type \
 Class::Data::Accessor \
 Class::Date \
 Class::Factory \
 Class::Fields \
 Class::Gomor \
 Class::InsideOut \
 Class::Loader \
 Class::MakeMethods \
 Class::MethodMaker \
 Class::Multimethods \
 Class::Multimethods::Pure \
 Class::NamedParms \
 Class::Observable \
 Class::ParmList \
 Class::ReturnValue \
 Class::Std \
 Class::Throwable \
 Class::Trait \
 Class::Virtual \
 Class::XPath \
 Compress::LZF \
 Config::Any \
 Config::General \
 Config::IniFiles \
 Config::JSON \
 Config::Simple \
 Config::Std \
 Config::XPath \
 Continuity \
 Convert::ASCII::Armour \
 Convert::Bencode \
 Convert::BinHex \
 Convert::PEM \
 Convert::TNEF \
 Coro \
 Crypt::Blowfish \
 Crypt::CipherSaber \
 Crypt::DES \
 Crypt::DH \
 Crypt::DSA \
 Crypt::IDEA \
 Crypt::OpenPGP \
 Crypt::OpenSSL::Bignum \
 Crypt::OpenSSL::RSA \
 Crypt::OpenSSL::Random \
 Crypt::PasswdMD5 \
 Crypt::Primes \
 Crypt::RSA \
 Crypt::Random \
 Crypt::Rijndael \
 Curses \
 DBD::Mock \
 DBD::Pg \
 DBI::Shell \
 DBIx::Class \
 DBIx::Class::Indexed \
 DBIx::DBSchema \
 DBIx::Perlish \
 DBIx::SearchBuilder \
 DBIx::Simple \
 DBIx::Timeout \
 Daemon::Generic \
 Data::Bind \
 Data::Buffer \
 Data::Dump \
 Data::Dump::Streamer \
 Data::Entropy \
 Data::Float \
 Data::FormValidator \
 Data::HexDump \
 Data::Hierarchy \
 Data::Lazy \
 Data::OptList \
 Data::Properties \
 Data::Random \
 Data::TreeDumper \
 Data::Types \
 Data::Visitor \
 Date::Leapyear \
 Date::Simple \
 Data::TreeDumper \
 DateTime::Calendar::Julian \
 DateTime::Event::Recurrence \
 DateTime::Format::Builder \
 DateTime::Format::Mail \
 DateTime::Format::MySQL \
 DateTime::Format::Natural \
 DateTime::Format::W3CDTF \
 DateTime::Set \
 Devel::CallTrace \
 Devel::Caller \
 Devel::Command \
 Devel::Cover \
 Devel::Dependencies \
 Devel::FastProf \
 Devel::Hide \
 Devel::LexAlias \
 Devel::Modlist \
 Devel::Monitor \
 Devel::Profile \
 Devel::Required \
 Devel::Size \
 Devel::SmallProf \
 Devel::Trace \
 Devel::TraceMethods \
 Devel::TraceUse \
 Devel::ebug \
 Devel::ebug::HTTP \
 Digest::BubbleBabble \
 Digest::MD2 \
 Email::Address \
 Email::Date \
 Email::Find \
 Email::Folder \
 Email::FolderType \
 Email::FolderType::Net \
 Email::LocalDelivery \
 Email::MIME \
 Email::MIME::ContentType \
 Email::MIME::Encodings \
 Email::MIME::Modifier \
 Email::MIME::XPath \
 Email::MessageID \
 Email::Simple::Creator \
 Encode::compat \
 Event::ExecFlow \
 Event::Lib \
 Exporter::Lite \
 ExtUtils::Depends \
 ExtUtils::F77 \
 ExtUtils::ModuleMaker \
 ExtUtils::PkgConfig \
 FLV::Info \
 File::BaseDir \
 File::Fetch \
 File::NCopy \
 File::NFSLock \
 File::Path::Expand \
 File::Rsync \
 File::ShareDir \
 FileHandle::Unget \
 Filesys::Df \
 Filesys::Virtual \
 Filter::Util::Call \
 Flickr::API \
 Font::TTF \
 FormValidator::Simple \
 GD::Graph \
 GD::SVG \
 GIS::Distance \
 GSSAPI \
 Geography::Countries \
 Getopt::ArgvFile \
 Getopt::Euclid \
 Getopt::Mixed \
 Graph \
 Graph::Easy \
 Graph::SocialMap \
 GraphViz \
 Gtk \
 Gtk2 \
 HTML::Clean \
 HTML::Entities::Numbered \
 HTML::FillInForm \
 HTML::FromText \
 HTML::Mason \
 HTML::PopupTreeSelect::Dynamic \
 HTML::Prototype \
 HTML::Scrubber \
 HTML::Selector::XPath \
 HTML::SimpleParse \
 HTML::StickyQuery \
 HTML::TableExtract \
 HTML::Template::Compiled \
 HTML::Tidy \
 HTML::TokeParser::Simple \
 HTML::Widget \
 HTML::WikiConverter \
 HTTP::BrowserDetect \
 HTTP::Response::Encoding \
 HTTP::Server::Simple \
 HTTP::Server::Simple::Mason \
 Hash::AsObject \
 Heap \
 Heap::Simple \
 IO::Async::Buffer \
 IO::Digest \
 IO::Interface \
 IO::LockedFile \
 IO::Multiplex \
 IO::Pager \
 IO::Tee \
 IPC::Mmap \
 IPC::PubSub \
 IPC::ShareLite \
 Image::Pngslimmer \
 Imager \
 Imager::Graph \
 Iterator \
 JSON::XS \
 Jifty \
 Kwiki \
 LWP::Authen::Wsse \
 LWP::UserAgent \
 Lexical::Persistence \
 Lingua::EN::Inflect::Number \
 Lingua::StopWords \
 Lingua::ZH::TaBE \
 List::MoreUtils \
 Locale::Maketext::Fuzzy \
 Locale::Maketext::Gettext \
 Locale::Maketext::Lexicon \
 Log::Agent \
 Log::Message \
 Log::Message::Simple \
 Lucene \
 MKDoc::XML \
 MP3::Info \
 Mail::Audit \
 Mail::IMAPClient \
 Mail::RFC822::Address \
 Mail::Transport::Dbx \
 Math::Approx::Symbolic \
 Math::Base85 \
 Math::BigInt::FastCalc \
 Math::BigInt::GMP \
 Math::BigRat \
 Math::GMP \
 Math::Geometry::Planar::GPC \
 Math::Geometry::Planar::Offset \
 Math::Pari \
 Math::Polygon \
 Math::Polynom \
 Math::Round::Var \
 Math::Symbolic \
 Math::SymbolicX::ParserExtensionFactory \
 Math::Vec \
 Module::Build::Convert \
 Module::Compile \
 Module::Find \
 Module::Info \
 Module::Install \
 Module::Loaded \
 Module::Plan::Base \
 Module::Pluggable::Fast \
 Module::Refresh \
 Module::Release \
 Module::Versions::Report \
 Moose \
 Net::CIDR \
 Net::Daemon \
 Net::Domain::TLD \
 Net::IMAP::Simple \
 Net::IPv4Addr \
 Net::IPv6Addr \
 Net::Libdnet \
 Net::Netmask \
 Net::Packet \
 Net::Pcap \
 Net::SNMP \
 Net::SSH \
 Net::SSL::ExpireDate \
 Net::Server \
 Net::Twitter \
 Net::Write \
 Net::XMPP \
 NetAddr::IP \
 News::Article \
 Number::Format \
 Number::WithError \
 OLE::Storage_Lite \
 Object::Accessor \
 Object::Realize::Later \
 Object::Signature \
 Object::Tiny \
 OpenOffice::OODoc \
 PAR \
 PAR::Dist::FromCPAN \
 PAR::Packer \
 Params::CallbackRequest \
 PApp \
 PDL \
 POE::API::Peek \
 POE::Component::CPAN::YACSmoke \
 POE::Component::Client::DNS \
 POE::Component::Client::Ident \
 POE::Component::Client::Keepalive \
 POE::Component::IRC \
 POE::Component::SSLify \
 POE::Filter::IRCD \
 PPI \
 Package::Constants \
 PadWalker \
 Params::Smart \
 Parse::BACKPAN::Packages \
 Parse::Yapp \
 Perl6::Attributes \
 Perl6::Caller \
 Perl6::Export \
 Perl6::Form \
 Perl6::Perldoc \
 Perl::Dist \
 Perl::Version \
 PerlIO::eol \
 PerlIO::via::dynamic \
 PerlIO::via::symlink \
 Perlbal \
 Petal \
 Petal::Utils \
 Plagger \
 Pod::POM \
 Pod::Xhtml \
 Proc::ProcessTable \
 ProgressMonitor::AbstractConfiguration \
 Pugs::Compiler::Perl6 \
 Pugs::Compiler::Rule \
 Quantum::Superpositions \
 RDF::Core \
 RDF::Simple \
 RPC::XML \
 Regexp::Log \
 Regexp::Shellish \
 ResourcePool \
 Return::Value \
 Roman \
 Rose::DateTime \
 Rose::Object \
 SOAP::Lite \
 SQL::Abstract::Limit \
 SQL::ReservedWords \
 SQL::Statement \
 SREZIC/pingomatic-1.013 \
 SVN::Mirror \
 SVN::Notify::Config \
 SVN::Notify::Mirror \
 Scalar::Defer \
 Set::ConsistentHash \
 Set::Infinite \
 Smart::Comments \
 Socket6 \
 Spoon \
 Spreadsheet::ParseExcel \
 Spreadsheet::WriteExcel \
 String::Approx \
 String::CRC32 \
 String::Diff \
 String::Expand \
 String::ShellQuote \
 String::Similarity \
 Sub::Exporter \
 Sub::Install \
 Sub::Name \
 Sub::Override \
 Sys::SigAction \
 Taint::Util \
 Task::CVSMonitor \
 Tcl \
 TeX::Encode \
 Template::Extract \
 Template::Plugin::Class \
 Template::Plugin::Number::Format \
 Template::Timer \
 Term::Menu \
 Term::ProgressBar \
 Term::Prompt \
 Term::ReadLine::Gnu \
 Term::Size \
 Term::Size::Perl \
 Term::UI \
 Test::Class \
 Test::Deep \
 Test::Differences \
 Test::HTTP::Server::Simple \
 Test::JSON \
 Test::Kwalitee \
 Test::LongString \
 Test::MockModule \
 Test::MockObject \
 Test::SubCalls \
 Test::WWW::Mechanize \
 Test::Without::Module \
 Test::YAML::Meta \
 Text::Aligner \
 Text::Autoformat \
 Text::CSV_XS \
 Text::LevenshteinXS \
 Text::Ngram \
 Text::Quoted \
 Text::Reform \
 Text::Shellwords \
 Text::Table \
 Text::TabularDisplay \
 Text::Template \
 Text::VimColor \
 Text::WikiFormat \
 Text::Wrapper \
 Text::vFile::asData \
 Tie::Array::Sorted \
 Tie::Cache::LRU \
 Tie::Cycle \
 Tie::DxHash \
 Tie::EncryptedHash \
 Time::HiRes::Value \
 Time::Piece \
 Time::UTC \
 Tk::FontDialog \
 Tk::Pod \
 Tk::TableMatrix \
 Tk::Tree \
 UNIVERSAL::isa \
 URI::Find \
 URI::Template \
 URI::imap \
 URI::imaps \
 Unicode::Map \
 Unicode::Map8 \
 Unicode::MapUTF8 \
 Unix::Syslog \
 User \
 User::Identity \
 Voting::Condorcet::RankedPairs \
 WWW::Live365 \
 WWW::Monitor \
 WWW::OpenSearch \
 WWW::Scraper::ISBN::Record \
 WWW::Search \
 WWW::Shorten \
 Want \
 Workflow \
 X500::DN \
 XML::Atom \
 XML::AutoWriter \
 XML::Checker::Parser \
 XML::Comma \
 XML::Compile \
 XML::DOM::XPath \
 XML::Elemental \
 XML::Filter::XInclude \
 XML::Handler::YAWriter \
 XML::Node \
 XML::NodeFilter \
 XML::Parser::Lite::Tree \
 XML::RSS \
 XML::RSS::LibXML \
 XML::Sablotron \
 XML::SimpleObject \
 XML::Stream \
 XML::Tiny \
 XML::Twig \
 XML::Validator::Schema \
 XML::XPathEngine \
 YAML::Tiny \
 Yahoo::Search \
 bignum \
 capitalization \
 gettext \
 mixin \


}
}

sub postamble {
  return "" unless $HAVE_MAKE; # dmake has unknown issues with my Makefile
  my @m;
  push @m, q{
# the subdirs on MY OWN BOX are allowed here (only used for make dist!)
verify-no-subdir:
	@$(PERL) -e 'my$$s=join",",grep{!/^(CPAN|DIST|bin|blib|cover_db|distroprefs|eg|gpw9-cpan-talk.d|inc|lib|logs|patches|perlbug|protocols|related|release-lib|scripts|t)\z/&&-d($$_)}glob"*";die"unexpected dir:$$s"if$$s'

setversion:
	$(PERL) Makefile.PL --setversion

README: lib/CPAN.pm Makefile
	-[ -r $@ ] && chmod +w $@
	-$(PERL) -MPod::Text -e 'Pod::Text->new->parse_from_file(\*ARGV)' lib/CPAN.pm > $@

chlog-svkstyle :: chlog-svk-short

chlog-svk-short : ChangeLogShort.svk
ChangeLogShort.svk : Makefile.PL lib/CPAN.pm distroprefs/00.README
	-LC_ALL=$(LC_ALL_noexport) svk log -v //local/cpanpm > $@

chlog-svk-long : ChangeLogLong.svk
ChangeLogLong.svk :
	-LC_ALL=$(LC_ALL_noexport) svk log -v //mirror/cpanpm > $@

# got this from http://ch.tudelft.nl/~arthur/svn2cl/
chlog-svn :
	-LC_ALL=$(LC_ALL_noexport) svn log -v https://pause.perl.org:5460/svn/cpanpm/trunk > ChangeLog.svn

chlog-trad : ChangeLogTrad.svn
ChangeLogTrad.svn :
	-/home/src/devel/svn/svn2cl/svn2cl-current/svn2cl.sh --strip-prefix trunk --group-by-day https://pause.perl.org:5460/svn/cpanpm/trunk > $@

# for debugging
chlog-xml :
	svn log --xml --verbose > ChangeLog.xml

the-release-name :
	$(NOECHO) $(ECHO) 'version ' $(VERSION)
	$(NOECHO) $(ECHO) 'release-name ' $(DISTVNAME).tar$(SUFFIX)

release ::
	/usr/bin/perl -Irelease-lib -S release $(DISTVNAME).tar$(SUFFIX)
	rm -rf $(DISTVNAME)
	svn cp -m 'This is $(VERSION)' https://pause.perl.org:5460/svn/cpanpm/trunk https://pause.perl.org:5460/svn/cpanpm/tags/$(VERSION)

checkout ::
	svn co https://pause.perl.org:5460/svn/cpanpm/trunk ./

# 16=Distribution; 1024=Shell; 32768=Queue
# $$CPAN::DEBUG|=16;$$CPAN::DEBUG|=1024;$$CPAN::DEBUG|=32768;
megainstall: termreadkeyinstall logs/.exists
	$(PERL) -Ilib -MCPAN -e 'CPAN::HandleConfig->load;install(qw($(MEGA_BASE)), map {$$_->[0]} sort {$$a->[1]<=>$$b->[1]} map {[$$_,rand(1)]} qw($(MEGA_INSTALL)));CPAN::Shell->failed' > logs/megainstall.`date +%Y%m%dT%H%M`.out 2>&1

# 16=Distribution; 32=Bundle; 32768=Queue
depefails:
	$(PERL) -Ilib -MCPAN -e 'CPAN::HandleConfig->load;$$CPAN::DEBUG|=16;$$CPAN::DEBUG|=32;$$CPAN::DEBUG|=32768;install(qw(CPAN::Test::Dummy::Perl5::Build::DepeFails));'

# nohup needed by my zsh
termreadkeyinstall: logs/.exists
	nohup $(PERL) -Ilib -MCPAN -e 'install(qw(Term::ReadKey))' < /dev/null > logs/rk.`date +%Y%m%dT%H%M`.out 2>&1

logs/.exists :
	mkdir -p logs
	touch $@

run :
	$(PERL) -Ilib -MCPAN -eshell

record-session :
	$(PERL) -Ilib -MCPAN -e '$$CPAN::Suppress_readline=$$CPAN::Echo_readline=1;shell' | tee ttt.out

run-with-sqlite :
	$(PERL) -I$$HOME/.cpan -Ilib -MCPAN::SQLite -MCPAN::MyConfig -MCPAN -e '$$CPAN::Config->{use_sqlite}++; $$CPAN::Config->{sqlite_dbname}="cpandb-sqlite"; shell'

testrun_very_offline : rm_mirrored_by run_emu_offline

testrun_emu_offline :
	$(PERL) -I$$HOME/.cpan -Ilib -MCPAN::MyConfig -MCPAN -e '@CPAN::Defaultsites = qw(file:///dev/null); $$CPAN::Config->{urllist} = []; shell'

rm_mirrored_by :
	rm -f $$HOME/.cpan/sources/MIRRORED.BY*

testrun_http_only :
	$(PERL) -I$$HOME/.cpan -Ilib -MCPAN::MyConfig -MCPAN -e '$$CPAN::Config->{urllist} = [qw(http://www.planet-elektronik.de/CPAN/)]; shell'

urllist :
	$(PERL) -Ilib -MCPAN -MCPAN::FirstTime -e 'CPAN::FirstTime::init("$$ENV{HOME}/.cpan/CPAN/MyConfig", args => [qw(urllist)])'

runadmin :
	$(PERL) -Ilib -MCPAN::Admin -eshell

rundb :
	$(PERL) -Ilib -MCPAN -deshell

sign:
	cpansign -s

show-batch-signing-keys:
	for f in PAUSE*.pub; do echo "++++$$f++++"; gpg --verbose --with-colons $$f; done

show-imported:
	gpg --list-sigs --with-colons 450F89EC

# seems to need at least gnupg 1.4.2:
upload-batch-signing-key:
	gpg --send-key 450F89EC

diff::
	svn diff | less

howto-release:
	@$(ECHO) make ci dist \&\& make release

META.yml: metafile
	$(CP) $(DISTVNAME)/META.yml  ./META.yml

install-devel-cover-unless-uptodate:
	$(PERL) -Ilib -MCPAN -e 'CPAN::Shell->install("/home/src/perl/devel-cover/SVN/.") unless CPAN::Shell->expand("Module","Devel::Cover")->uptodate'

install-devel-cover-unconditionally:
	$(PERL) -Ilib -MCPAN -e 'CPAN::Shell->install("/home/src/perl/devel-cover/SVN/.")'

testcover: testdistros install-devel-cover-unless-uptodate
	:>SIGNATURE
	$(PERL) -MDevel::Cover -e 0
	`dirname $(PERL)`/cover -delete
	HARNESS_PERL_SWITCHES=-MDevel::Cover $(MAKE) test
	`dirname $(PERL)`/cover

man:
	$(PERL)doc -F lib/CPAN.pm

testdistros: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails-1.02.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails-1.03.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-1.05.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne-1.00.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo-1.00.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree-1.00.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect-1.00.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Failearly-1.02.tar.gz \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Zip-1.03.zip \
        t/CPAN/authors/id/A/AN/ANDK/NotInChecksums-0.000.tar.gz

# sorry, unix centric (and only makes sense on a working copy of the
# repository; else 'make test TEST_FILES=t/30shell.t TEST_VERBOSE=1'
# will do)
testshell-with-protocol: testdistros
	$(PERL) -e 'for ("protocols"){-d $$_ or mkdir $$_, 0755}'
	$(MAKE) test TEST_FILES=t/30shell.t TEST_VERBOSE=1 PERL='$(PERL)' | \
		tee protocols/make-test-`date +%Y%m%dT%H%M%S`
	ls -lt protocols | head

testshell-with-protocol-without-expect: testdistros
	$(PERL) -e 'for ("protocols"){-d $$_ or mkdir $$_, 0755}'
	CPAN_RUN_SHELL_TEST_WITHOUT_EXPECT=1 $(MAKE) test \
		TEST_FILES=t/30shell.t TEST_VERBOSE=1 | \
		tee protocols/make-test-`date +%Y%m%dT%H%M%S`
	ls -lt protocols | head

testshell-with-protocol-twice: testdistros
	$(PERL) -e 'for ("protocols"){-d $$_ or mkdir $$_, 0755}'
	$(PERL) -p -i~ -e 's/colorize_output\D+\d/colorize_output=>0/' t/CPAN/TestConfig.pm
	$(MAKE) test TEST_FILES=t/30shell.t TEST_VERBOSE=1 | \
		tee protocols/make-test-`date +%Y%m%dT%H%M%S`
	$(PERL) -p -i~ -e 's/colorize_output\D+\d/colorize_output=>1/' t/CPAN/TestConfig.pm
	$(MAKE) test TEST_FILES=t/30shell.t TEST_VERBOSE=1 | \
		tee protocols/make-test-`date +%Y%m%dT%H%M%S`
	$(PERL) -p -i~ -e 's/colorize_output\D+\d/colorize_output=>0/' t/CPAN/TestConfig.pm
	ls -ltr protocols | tail

#
# testdistros
#

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build/Build.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build/lib/CPAN/Test/Dummy/Perl5/Build.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build && \
		$(PERL) Build.PL && \
		./Build dist && \
		mv CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz .. && \
		./Build clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails-1.02.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails/README \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails/Build.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails/lib/CPAN/Test/Dummy/Perl5/Build/DepeFails.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-DepeFails && \
		$(PERL) Build.PL && \
		./Build dist && \
		mv CPAN-Test-Dummy-Perl5-Build-DepeFails-1.02.tar.gz .. && \
		./Build clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails-1.03.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails/README \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails/Build.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails/lib/CPAN/Test/Dummy/Perl5/Build/Fails.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-Fails && \
		$(PERL) Build.PL && \
		./Build dist && \
		mv CPAN-Test-Dummy-Perl5-Build-Fails-1.03.tar.gz .. && \
		./Build clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake/Build.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake/lib/CPAN/Test/Dummy/Perl5/BuildOrMake.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-BuildOrMake && \
		$(PERL) Build.PL && \
		./Build dist && \
		mv CPAN-Test-Dummy-Perl5-BuildOrMake-1.02.tar.gz .. && \
		./Build clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-1.05.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make/lib/Bundle/CpanTestDummies.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make/lib/CPAN/Test/Dummy/Perl5/Make.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make && \
		$(PERL) Makefile.PL && \
		$(MAKE) dist && \
		mv CPAN-Test-Dummy-Perl5-Make-1.05.tar.gz .. && \
		$(MAKE) clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne-1.00.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne/lib/CPAN/Test/Dummy/Perl5/Make/CircDepeOne.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeOne && \
		$(PERL) Makefile.PL && \
		$(MAKE) dist && \
		mv CPAN-Test-Dummy-Perl5-Make-CircDepeOne-1.00.tar.gz .. && \
		$(MAKE) clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo-1.00.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo/lib/CPAN/Test/Dummy/Perl5/Make/CircDepeTwo.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeTwo && \
		$(PERL) Makefile.PL && \
		$(MAKE) dist && \
		mv CPAN-Test-Dummy-Perl5-Make-CircDepeTwo-1.00.tar.gz .. && \
		$(MAKE) clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree-1.00.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree/lib/CPAN/Test/Dummy/Perl5/Make/CircDepeThree.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-CircDepeThree && \
		$(PERL) Makefile.PL && \
		$(MAKE) dist && \
		mv CPAN-Test-Dummy-Perl5-Make-CircDepeThree-1.00.tar.gz .. && \
		$(MAKE) clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect-1.00.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect/Changes \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect/lib/CPAN/Test/Dummy/Perl5/Make/Expect.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Expect && \
		$(PERL) Makefile.PL && \
		$(MAKE) dist && \
		mv CPAN-Test-Dummy-Perl5-Make-Expect-1.00.tar.gz .. && \
		$(MAKE) clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Failearly-1.02.tar.gz: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Failearly/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Failearly/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Failearly/lib/CPAN/Test/Dummy/Perl5/Make/Failearly.pm
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Failearly && \
		$(PERL) Makefile.PL && \
		$(MAKE) dist && \
		mv CPAN-Test-Dummy-Perl5-Make-Failearly-1.02.tar.gz .. && \
		$(MAKE) clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Zip-1.03.zip: \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Zip/MANIFEST \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Zip/Makefile.PL \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Zip/lib/CPAN/Test/Dummy/Perl5/Make/Zip.pm \
	t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Zip/t/00_load.t
	cd t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-Zip && \
		$(PERL) Makefile.PL && \
		$(MAKE) dist && \
		mv CPAN-Test-Dummy-Perl5-Make-Zip-1.03.zip .. && \
		$(MAKE) clean
	ls -l $@

t/CPAN/authors/id/A/AN/ANDK/NotInChecksums-0.000.tar.gz :
	echo " ----No content---- " > t/CPAN/authors/id/A/AN/ANDK/tempfile
	cd t/CPAN/authors/id/A/AN/ANDK && tar cvzf NotInChecksums-0.000.tar.gz tempfile
	$(RM) t/CPAN/authors/id/A/AN/ANDK/tempfile
	ls -l $@

#
#
#

testallperls :
	:>SIGNATURE
	for p in $(ALL_PERLS); do $$p -v && $$p Makefile.PL && $(MAKE) test; done

clean ::
	$(RM) t/CPAN/authors/id/A/AN/ANDK/*/Build \
		t/CPAN/authors/id/A/AN/ANDK/*/Makefile.old \
		t/CPAN/authors/id/A/AN/ANDK/*/META.yml
	$(RM_RF) t/CPAN/authors/id/A/AN/ANDK/*/_build

no_CR : ChangeLog META.yml
	$(PERL) bin/no_CR.pl MANIFEST

};
  if ($SVN_RELEASE) {
    push @m, qq{
chlog :: chlog-svn chlog-trad

ChangeLog : ChangeLogTrad.svn
	mv ChangeLogTrad.svn ChangeLog
};
  } else {
    push @m, qq{
chlog :: chlog-svkstyle

ChangeLog : ChangeLogShort.svk
	mv ChangeLogShort.svk ChangeLog

foreign-prefs : dd-prefs st-prefs

dd-prefs ::

st-prefs ::

};
  }

  for my $base (@main::DD_PREFS) {
    push @m, qq{
dd-prefs :: $base.dd

};

    if ($HAVE_YAML_SYCK) {
      push @m, qq{$base.dd : Makefile
	\$(PERL) -MYAML::Syck=LoadFile -MData::Dumper -e '\$\$x=shift; \@y=LoadFile("\$\$x.yml"); print Data::Dumper->new(\\\@y)->Indent(1)->Useqq(1)->Purity(1)->Sortkeys(1)->Dump' $base > $base.dd.new && mv $base.dd.new $base.dd

};
    } elsif (0) {
      # we should only say this on author's machine:
      warn "Warning (usually harmless): have no YAML::Syck, cannot write rules for foreign prefs"
    }
  }

  for my $base (@main::ST_PREFS) {
    push @m, qq{
st-prefs :: $base.st

};
    if ($HAVE_YAML_SYCK) {
      push @m, qq{$base.st : Makefile
	\$(PERL) -MYAML::Syck=LoadFile -MStorable=nstore -e '\$\$x=shift; \@y=LoadFile("\$\$x.yml"); nstore(\\\@y, "\$\$x.st")' $base

};
    }
  }

  join "", @m;
}

sub dist_ci {
  return qq{ci :
	svn ci
};
}

sub dist_test {
  return q{
# if we depend on $(DISTVNAME).tar$(SUFFIX), then the rest of the
# Makefile breaks our intent to NOT remake dist
disttest :
	rm -rf $(DISTVNAME)
	tar xvzf $(DISTVNAME).tar$(SUFFIX)
	cd $(DISTVNAME) && $(ABSPERLRUN) Makefile.PL
	cd $(DISTVNAME) && $(MAKE) $(PASTHRU)
	cd $(DISTVNAME) && $(MAKE) test $(PASTHRU)

distdir ::
	touch $(DISTVNAME)/SIGNATURE && $(CP) $(DISTVNAME)/SIGNATURE ./SIGNATURE
	$(CP) $(DISTVNAME)/META.yml  ./META.yml
	$(CP) $(DISTVNAME)/MANIFEST  ./MANIFEST

}
}

sub distdir {
  my $self = shift;
  my $out = $self->SUPER::distdir;
  $out =~ s/distdir :/distdir ::/g;
  return $out;
}

# dist_dir was the name in very old MakeMaker as of 5.005_04
sub dist_dir {
  my $self = shift;
  my $out = $self->SUPER::dist_dir;
  $out =~ s/distdir :/distdir ::/g;
  return $out;
}
