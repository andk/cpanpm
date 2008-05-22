

=head1 NAME

quidi-getreports - Quickly fetch cpantesters results with all reports

=head1 SYNOPSIS

  $0 [options] distroname

=head1 DESCRIPTION

!!!!Alert: alpha quality software!!!!

The intent is to get at both the summary at cpantesters and the
individual reports and parse the reports and collect the data for
further inspection.

We always only fetch the reports for the most recent (optionally
picked) release. Target root directory is C<$HOME/var/cpantesters>

The C<--q> paramater can be repeated. It takes one argument which
stands for a query. This query must consist of two parts, a qualifier
and the query itself. Qualifiers are one of the following

  conf       parameters from the output of 'perl -V'
             e.g.: conf:usethreads, conf:cc
  mod        for installed modules, either from perrequisites or from the toolchain
             e.g.: mod:Test::Simple, mod:Imager
  meta       all other parameters
             e.g.: meta:perl, meta:from

The conf parameters specify a word used by the C<Config> module.

The mod parameters consist of a package name.

The meta parameters are the following: C<perl> for the perl version,
C<from> for the sender of the report, C<date> for the date in the mail
header, C<writer> for the module that produced the report.


=head2 Examples

This gets all recent reports for Object-Relation and outputs the
version number of the prerequisite Clone:

  $0 --q mod:Clone Object-Relation

Collects reports about Clone and reports the default set of metadata:

  $0 Clone

Collect reports for Devel-Events and report the version number of
Moose in thses reports and sort by success/failure. If Moose broke
Devel-Events is becomes pretty obvious:

  $0 --q mod:Moose Devel-Events |sort

Which tool was used to write how many reports, sorted by frequency:

  $0 --q meta:writer Template-Timer | sed -e 's/.*meta:writer//' | sort | uniq -c | sort -n

Who was in the From field of the mails whose report writer was not determined:

  $0 --q meta:writer --q meta:from Template-Timer | grep 'UNDEF'

At the time of this writing this collected the results of
IPC-Run-0.80_91 which was not really the latest release. In this case
manual investigations were necessary to find out that 0.80 was the
most recent:

  $0 IPC-Run

Pick the specific release IPC-Run-0.80:

  $0 --vdistro IPC-Run-0.80 IPC-Run

The following is a simple job to refresh all HTML pages we already
have and fetch new reports referenced there too:

  perl -le '
  for my $dirent (glob "$ENV{HOME}/var/cpantesters/cpantesters-show/*.html"){
    my($distro) = $dirent =~ m|/([^/]+)\.html$| or next;
    print $distro;
    my $system = "perl bin/quidi-getreports.pl --verbose --verbose $distro";
    0 == system $system or die;
  }'

=cut

use strict;
use warnings;

use DateTime::Format::Strptime;
use File::Path qw(mkpath);
use Getopt::Long;
use LWP::UserAgent;
use HTML::TreeBuilder ();
use XML::LibXML;
use XML::LibXML::XPathContext;
#                 my $xpc = XML::LibXML::XPathContext->new;
#                 $xpc->registerNs('x', 'http://www.w3.org/1999/xhtml');
#                 $xpc->find('/x:html',$node);

sub Usage () {
    die "Usage: FIXME";
};
our %Opt;
GetOptions(\%Opt,
           "local!",    # use a local *.html if present even if older than 24 hours
           "mirrorhtmlonly!",
           "q=s\@",     #
           "allvars=s", # list all queryable variables
           "vdistro=s", # versioned distro if we do not want the most recent
           "verbose+",  # feedback during download where we stand
          ) or die Usage;

my $ua = LWP::UserAgent->new;
$ua->parse_head(0);

my @q = @{$Opt{q}||[]};
@q = qw(meta:perl conf:archname conf:usethreads conf:optimize meta:writer meta:from) unless @q;

if (! @ARGV) {
    die Usage;
}

if ($Opt{allvars}) {
    eval { require YAML::Syck };
    if ($@) {
        die "YAML::Syck required for allvars option: $@";
    }
}

my $ROOT = "$ENV{HOME}/var/cpantesters";

$|=1;
for my $distro (@ARGV) {
    my %allvars;
    my $cts_dir = "$ROOT/cpantesters-show";
    mkpath $cts_dir;
    my $ctarget = "$cts_dir/$distro.html";
    my $cheaders = "$cts_dir/$distro.headers";
    if (! -e $ctarget or (!$Opt{local} && -M $ctarget > .25)) {
        if (-e $ctarget && $Opt{verbose}) {
            my(@stat) = stat _;
            my $timestamp = gmtime $stat[9];
            print "(timestamp $timestamp GMT)\n";
        }
        print "Fetching $ctarget..." if $Opt{verbose};
        my $resp = $ua->mirror("http://cpantesters.perl.org/show/$distro.html",$ctarget);
        if ($resp->is_success) {
            print "DONE\n" if $Opt{verbose};
            open my $fh, ">", $cheaders or die;
            for ($resp->headers->as_string) {
                print $fh $_;
                if ($Opt{verbose} && $Opt{verbose}>1) {
                    print;
                }
            }
        } elsif (304 == $resp->code) {
            print "DONE (not modified)\n";
            my $atime = my $mtime = time;
            utime $atime, $mtime, $cheaders;
        } else {
            die $resp->status_line;
        }
    }
    my $tree = HTML::TreeBuilder->new;
    $tree->implicit_tags(1);
    $tree->p_strict(1);
    $tree->ignore_ignorable_whitespace(0);
    my $ccontent = do { open my $fh, $ctarget or die; local $/; <$fh> };
    $tree->parse_content($ccontent);
    $tree->eof;
    my $content = $tree->as_XML;
    my $parser = XML::LibXML->new;;
    $parser->keep_blanks(0);
    $parser->clean_namespaces(1);
    my $doc = eval { $parser->parse_string($content) };
    my $err = $@;
    unless ($doc) {
        die "Error while parsing $distro\: $err";
    }
    $parser->clean_namespaces(1);
    my $xc = XML::LibXML::XPathContext->new($doc);
    my $nsu = $doc->documentElement->namespaceURI;
    $xc->registerNs('x', $nsu) if $nsu;
    # $DB::single++;
    my($selected_release_ul,$selected_release_distrov,$excuse_string);
    if ($Opt{vdistro}) {
        $excuse_string = "selected distro '$Opt{vdistro}'";
        ($selected_release_distrov) = $nsu ? $xc->findvalue("/x:html/x:body/x:div[\@id = 'doc']/x:div//x:h2[x:a/\@id = '$Opt{vdistro}']/x:a/\@id") :
            $doc->findvalue("/html/body/div[\@id = 'doc']/div//h2[a/\@id = '$Opt{vdistro}']/a/\@id");
        ($selected_release_ul) = $nsu ? $xc->findnodes("/x:html/x:body/x:div[\@id = 'doc']/x:div//x:h2[x:a/\@id = '$Opt{vdistro}']/following-sibling::ul[1]") :
            $doc->findnodes("/html/body/div[\@id = 'doc']/div//h2[a/\@id = '$Opt{vdistro}']/following-sibling::ul[1]");
    } else {
        $excuse_string = "any distro";
        ($selected_release_distrov) = $nsu ? $xc->findvalue("/x:html/x:body/x:div[\@id = 'doc']/x:div//x:h2[1]/x:a/\@id") :
            $doc->findvalue("/html/body/div[\@id = 'doc']/div//h2[1]/a/\@id");
        ($selected_release_ul) = $nsu ? $xc->findnodes("/x:html/x:body/x:div[\@id = 'doc']/x:div//x:ul[1]") :
            $doc->findnodes("/html/body/div[\@id = 'doc']/div//ul[1]");
    }
    unless ($selected_release_distrov) {
        warn "Warning: could not find $excuse_string in '$ctarget'";
        sleep 1;
        next;
    }
    print "SELECTED: $selected_release_distrov\n";
    my($ok,$id);
    for my $test ($nsu ? $xc->findnodes("x:li",$selected_release_ul) : $selected_release_ul->findnodes("li")) {
        $ok = $nsu ? $xc->findvalue("x:span[1]/\@class",$test) : $test->findvalue("span[1]/\@class");
        $id = $nsu ? $xc->findvalue("x:a[1]/text()",$test)     : $test->findvalue("a[1]/text()");
        my $nnt_dir = "$ROOT/nntp-testers";
        mkpath $nnt_dir;
        my $target = "$nnt_dir/$id";
        unless (-e $target) {
            print "Fetching $target..." if $Opt{verbose};
            my $resp = $ua->mirror("http://www.nntp.perl.org/group/perl.cpan.testers/$id",$target);
            if ($resp->is_success) {
                if ($Opt{verbose}) {
                    my(@stat) = stat $target;
                    my $timestamp = gmtime $stat[9];
                    print "(timestamp $timestamp GMT)\n";
                    if ($Opt{verbose} > 1) {
                        print $resp->headers->as_string;
                    }
                }
                my $headers = "$target.headers";
                open my $fh, ">", $headers or die;
                print $fh $resp->headers->as_string;
            } else {
                die $resp->status_line;
            }
        }
        open my $fh, $target or die;
        my(%extract);
        my $report_writer;
        my $moduleunpack = {};
        my $expect_prereq = 0;
        my $expect_toolchain = 0;
        my $expecting_toolchain_soon = 0;
        my $in_summary = 0;
        my $previous_line = ""; # so we can neutralize line breaks
      LINE: while (<$fh>) {
            chomp; # reliable line endings?
            s/&quot;//; # HTML !!!
            unless ($extract{"meta:perl"}) {
                my $p5;
                if (0) {
                } elsif (/Summary of my perl5 \((.+)\) configuration:/) {
                    $p5 = $1;
                    $in_summary = 1;
                }
                if ($p5) {
                    my($r,$v,$s,$p);
                    if (($r,$v,$s,$p) = $p5 =~ /revision (\S+) version (\S+) subversion (\S+) patch (\S+)/) {
                        $r =~ s/\.0//; # 5.0 6 2!
                        $extract{"meta:perl"} = "$r.$v.$s\@$p";
                    } elsif (($r,$v,$s) = $p5 =~ /revision (\S+) version (\S+) subversion (\S+)/) {
                        $r =~ s/\.0//;
                        $extract{"meta:perl"} = "$r.$v.$s";
                    } elsif (($r,$v,$s) = $p5 =~ /(\d+\S*) patchlevel (\S+) subversion (\S+)/) {
                        $r =~ s/\.0//;
                        $extract{"meta:perl"} = "$r.$v.$s";
                    } else {
                        $extract{"meta:perl"} = $p5;
                    }
                }
            }
            unless ($extract{"meta:from"}) {
                if (0) {
                } elsif (m|<div class="h_name">From:</div> <b>(.+?)</b><br/>|) {
                    $extract{"meta:from"} = $1;
                }
                $extract{"meta:from"} =~ s/\.$// if $extract{"meta:from"};
            }
            unless ($extract{"meta:date"}) {
                if (0) {
                } elsif (m|<div class="h_name">Date:</div> (.+?)<br/>|) {
                    my $date = $1;
                    my $p = DateTime::Format::Strptime->new(
                                                            locale => "en",
                                                            time_zone => "UTC",
                                                            # April 13, 2005 23:50
                                                            pattern => "%b %d, %Y %R",
                                                          );
                    my $dt = $p->parse_datetime($date);
                    $extract{"meta:date"} = $dt->datetime;
                }
                $extract{"meta:date"} =~ s/\.$// if $extract{"meta:date"};
            }
            unless ($extract{"meta:writer"}) {
                for ("$previous_line $_") {
                    if (0) {
                    } elsif (/created (?:automatically )?by (\S+)/) {
                        $extract{"meta:writer"} = $1;
                    } elsif (/CPANPLUS, version (\S+)/) {
                        $extract{"meta:writer"} = "CPANPLUS $1";
                    } elsif (/This report was machine-generated by CPAN::YACSmoke (\S+)/) {
                        $extract{"meta:writer"} = "CPAN::YACSmoke $1";
                    }
                    $extract{"meta:writer"} =~ s/[\.,]$// if $extract{"meta:writer"};
                }
            }
            if ($in_summary) {
                # we do that first three lines a bit too often
                my $qr = $Opt{allvars} || "";
                $qr = qr/$qr/ if $qr;
                my %conf_vars = map {($_ => 1)} grep { /^conf:/ } @q;

                if (/^\s*$/ || m|</pre>|) {
                    $in_summary = 0;
                } else {
                    while (my($k,$v) = /\G,?\s+([^=]+)=('[^']+?'|\S+)/gc) {
                        $k = "conf:$k";
                        $v =~ s/,$//;
                        if ($v =~ /^'(.*)'$/) {
                            $v = $1;
                        }
                        $v =~ s/^\s+//;
                        $v =~ s/\s+$//;
                        # $DB::single = $k eq "conf:cc"
                        if ($qr && $k =~ $qr) {
                            $allvars{$k}{$v}{$ok}++;
                        }
                        if ($conf_vars{$k}) {
                            $extract{$k} = $v;
                        }
                    }
                }
            }
            if ($expect_prereq || $expect_toolchain) {
                if (exists $moduleunpack->{type}) {
                    my($module,$v);
                    if ($moduleunpack->{type} == 1) {
                        (my $leader,$module,undef,$v) = eval { unpack $moduleunpack->{tpl}, $_; };
                        next LINE if $@;
                        if ($leader =~ /^-/) {
                            $moduleunpack = {};
                            $expect_prereq = 0;
                            next LINE;
                        } elsif ($leader =~ /^(
                                             buil          # build_requires:
                                            )/x) {
                            next LINE;
                        } elsif ($module =~ /^(
                                             -             # line drawing
                                            )/x) {
                            next LINE;
                        }
                    } elsif ($moduleunpack->{type} == 2) {
                        (my $leader,$module,$v) = eval { unpack $moduleunpack->{tpl}, $_; };
                        next LINE if $@;
                        if ($leader =~ /^\*/) {
                            $moduleunpack = {};
                            $expect_prereq = 0;
                            next LINE;
                        }
                    } elsif ($moduleunpack->{type} == 3) {
                        (my $leader,$module,$v) = eval { unpack $moduleunpack->{tpl}, $_; };
                        next LINE if $@;
                        if (!$module) {
                            $moduleunpack = {};
                            $expect_toolchain = 0;
                            next LINE;
                        } elsif ($module =~ /^-/) {
                            next LINE;
                        }
                    }
                    $module =~ s/\s+$//;
                    if ($module) {
                        $v =~ s/^\s+//;
                        $v =~ s/\s+$//;
                        $extract{"mod:$module"} = $v;
                    }
                }
                if (/(\s+)(Module\s+)(Need\s+)Have/) {
                    $moduleunpack = {
                                     tpl => 'a'.length($1).'a'.length($2).'a'.length($3).'a*',
                                     type => 1,
                                    };
                } elsif (/(\s+)(Module Name\s+)(Have\s+)Want/) {
                    my $adjust_1 = 0;
                    my $adjust_2 = -2; # hackish way of avoiding two-pass
                    my $adjust_3 = 2;
                    # two pass would be required to see where the
                    # columns really are. Or could we get away with split?
                    $moduleunpack = {
                                     tpl => 'a'.length($1).'a'.(length($2)+$adjust_2).'a'.(length($3)+$adjust_3),
                                     type => 2,
                                    };
                }
            }
            if (/PREREQUISITES|Prerequisite modules loaded/) {
                $expect_prereq=1;
            }
            if ($expecting_toolchain_soon) {
                if (/(\s+)(Module\s+) Have/) {
                    $expect_toolchain=1;
                    $expecting_toolchain_soon=0;
                    $moduleunpack = {
                                     tpl => 'a'.length($1).'a'.length($2).'a*',
                                     type => 3,
                                    };
                }
            }
            if (/toolchain versions installed/) {
                $expecting_toolchain_soon=1;
            }
            $previous_line = $_;
        } # LINE
        my $diag = "";
        if (my $qr = $Opt{allvars}) {
            $qr = qr/$qr/;
            while (my($k,$v) = each %extract) {
                if ($k =~ $qr) {
                    $allvars{$k}{$v}{$ok}++;
                }
            }
        }
        for my $want (@q) {
            my $have  = $extract{$want} || "";
            $diag .= " $want\[$have]";
        }
        printf " %-4s %8d%s\n", $ok, $id, $diag;
    }
    if ($Opt{allvars}) {
        print YAML::Syck::Dump(\%allvars);
    }
}
__END__
