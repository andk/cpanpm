package CPAN;
# This is the object that is used as global variable.
# If you want to inherit from CPAN, just change the constructor
use vars qw{$META $Signal $End $Suppress_readline};

$VERSION = '0.39a';

# $Id: CPAN.pm,v 1.60 1996/09/27 12:48:56 k Exp $
my $version = substr q$Revision: 1.60 $, 10;

BEGIN {require 5.002;}

use Carp ();

# term

$Suppress_readline = shift || !-t STDIN; # undocumented how to turn off ReadLine
my $term;
if ($Suppress_readline) {
} else {
    require Term::ReadLine;
    import Term::ReadLine;
    $term = new Term::ReadLine 'CPAN Monitor';
    $readline::rl_completion_function = 
    $readline::rl_completion_function = 'CPAN::Complete::complete';
}

# prompt

my $prompt = "cpan> ";

$^W = 1;


use Carp;
use File::Find;
use DirHandle;
use Exporter ();
use File::Path ();
use ExtUtils::MakeMaker ();
use IO::File ();
use Config ();

package CPAN;
use vars qw($VERSION @ISA @EXPORT $AUTOLOAD $DEBUG $META);
use strict qw(vars);
END { $End++; &cleanup; }

%CPAN::DEBUG = qw(
		  CPAN              1
		  Index             2
		  InfoObj           4
		  Author            8
		  Distribution     16
		  Bundle           32
		  Module           64
		  CacheMgr        128
		  Complete        256
		  FTP             512
		  Shell          1024
		 );
#???		  all            2047
# @CPAN::DEBUG{map {lc $_} keys %CPAN::DEBUG} = values CPAN::DEBUG;
$CPAN::DEBUG ||= 0;

@ISA = qw(CPAN::Debug Exporter MY); # the strange MY class from MakeMaker, gives us catfile and catdir
$META ||= new CPAN;                 # Incase we reeval ourselves we need a ||

eval {require CPAN::Config;};       # system wide config. We eval, because of some MakeMaker problems
unshift @INC, $META->catdir($ENV{HOME},".cpan");
eval {require CPAN::MyConfig;};     # where you can override system wide settings

@EXPORT = qw(autobundle bundle bundles expand install make shell test);

sub AUTOLOAD {
    my($l) = $AUTOLOAD;
    $l =~ s/.*:://;
    my(%EXPORT);
    @EXPORT{@EXPORT} = '';
    if (exists $EXPORT{$l}){
	CPAN::Shell->$l(@_);
    } else {
	warn "CPAN doesn't know how to autoload $AUTOLOAD :-(

Nothing Done.
";
    }
}

sub all {
    my($mgr,$class) = @_;
    CPAN->debug("mgr[$mgr] class[$class]") if $CPAN::DEBUG;
    CPAN::Index->reload;
    values %{ $META->{$class} };
}

# Called by shell, not in batch mode. Not clean XXX
sub checklock {
    my($self) = @_;
    my $lockfile = CPAN->catfile($CPAN::Config->{cpan_home},".lock");
    if (-f $lockfile && -M _ > 0) {
	my $fh = IO::File->new($lockfile);
	my $other = <$fh>;
	$fh->close;
	if (defined $other && $other) {
	    chomp $other;
	    return if $$==$other; # should never happen
	    print qq{There seems to be running another CPAN process ($other). Trying to contact...\n};
	    if (kill 0, $other) {
		Carp::croak qq{Other job is running.\n}.
		    qq{You may want to kill it and delete the lockfile, maybe. On UNIX try:\n}.
			qq{    kill $other\n}.
			    qq{    rm $lockfile\n};
	    } elsif (-w $lockfile) {
		my($ans)=
		    ExtUtils::MakeMaker::prompt
			(qq{Other job not responding. Shall I overwrite the lockfile? (Y/N)},"y");
		print("Ok, bye\n"), exit unless $ans =~ /^y/i;
	    } else {
		Carp::croak(
			    qq{Lockfile $lockfile not writeable by you. Cannot proceed.\n}.
			    qq{    On UNIX try:\n}.
			    qq{    kill $other\n}.
			    qq{    rm $lockfile\n}
			   );
	    }
	}
    }
    File::Path::mkpath($CPAN::Config->{cpan_home});
    my $fh;
    unless ($fh = IO::File->new(">$lockfile")) {
	if ($! =~ /Permission/) {
	    my $incc = $INC{'CPAN/Config.pm'};
	    my $myincc = MY->catfile($ENV{HOME},'.cpan','CPAN','MyConfig.pm');
	    print qq{

Your configuration suggests that CPAN.pm should use a working
directory of
    $CPAN::Config->{cpan_home}
Unfortunately we could not create the lock file
    $lockfile
due to permission problems.

Please make sure that the configuration variable
    \$CPAN::Config->{cpan_home}
points to a directory where you can write a .lock file. You can set
this variable in either
    $incc
or
    $myincc

};
	}
	Carp::croak "Could not open >$lockfile: $!";
    }
    print $fh $$, "\n";
    $self->{LOCK} = $lockfile;
    $fh->close;
    $SIG{'TERM'} = sub { &cleanup; die "Got SIGTERM, leaving"; };
    $SIG{'INT'} = sub { &cleanup, die "Got a second SIGINT" if $Signal; $Signal = 1; };
    $SIG{'__DIE__'} = \&cleanup;
    print STDERR "Signal handler set.\n" unless $CPAN::Config->{'inhibit-startup-message'};
}

sub DESTROY {
    &cleanup; # need an eval?
}

sub exists {
    my($mgr,$class,$id) = @_;
    CPAN::Index->reload;
    Carp::croak "exists called without class argument" unless $class;
    $id ||= "";
    exists $META->{$class}{$id};
}

sub hasFTP {
    my($self,$arg) = @_;
    if (defined $arg) {
	return $self->{'hasFTP'} = $arg;
    } elsif (not defined $self->{'hasFTP'}) {
	eval {require Net::FTP;};
	$self->{'hasFTP'} = $@ ? 0 : 1;
    }
    return $self->{'hasFTP'};
}

sub hasLWP {
    my($self,$arg) = @_;
    if (defined $arg) {
	return $self->{'hasLWP'} = $arg;
    } elsif (not defined $self->{'hasLWP'}) {
	eval {require LWP;};
	$LWP::VERSION ||= 0;
        $self->{'hasLWP'} = $LWP::VERSION >= 4.98;
    }
    return $self->{'hasLWP'};
}

sub hasMD5 {
    my($self,$arg) = @_;
    if (defined $arg) {
	$self->{'hasMD5'} = $arg;
    } elsif (not defined $self->{'hasMD5'}) {
	eval {require MD5;};
	if ($@) {
	    print "MD5 security checks disabled because MD5 not installed. Please consider installing MD5\n";
	    $self->{'hasMD5'} = 0;
	} else {
	    $self->{'hasMD5'}++;
	}
    }
    return $self->{'hasMD5'};
}

sub instance {
    my($mgr,$class,$id) = @_;
    CPAN::Index->reload;
    Carp::croak "instance called without class argument" unless $class;
    $id ||= "";
    $META->{$class}{$id} ||= $class->new(ID => $id );
}

sub new {
    bless {}, shift;
}

sub cleanup {
    local $SIG{__DIE__} = '';
    my $i = 0; my $ineval = 0; my $sub;
    while ((undef,undef,undef,$sub) = caller(++$i)) {
      $ineval = 1, last if $sub eq '(eval)';
    }
    return if $ineval && !$End;
    return unless defined $META->{'LOCK'};
    return unless -f $META->{'LOCK'};
    unlink $META->{'LOCK'};
    print STDERR "Lockfile removed.\n";
#    my $mess = Carp::longmess(@_);
#    die @_;
}

sub shell {
    no strict;
    $META->checklock();
    my $cwd = Cwd::cwd();
    # How should we determine if we have more than stub ReadLine enabled?
    my $rl_avail = $Suppress_readline ? "suppressed" :
	defined &Term::ReadLine::Perl::readline ? "enabled" :
	    "available (get Term::ReadKey and Term::ReadLine::Perl)";

    print qq{
cpan shell -- CPAN exploration and modules installation (v$CPAN::VERSION)
Readline support $rl_avail

} unless $CPAN::Config->{'inhibit-startup-message'} ;
    while () {
	if ($Suppress_readline) {
	    print $prompt;
	    last unless defined (chomp($_ = <>));
	} else {
	    last unless defined ($_ = $term->readline($prompt));
	}
	s/^\s//;
	next if /^$/;
	if (/^\!/) {
	    s/^\!//;
	    eval($_);
	    warn $@ if $@;
	    print "\n";
	    next;
	} elsif (/^q$/i) {
	    last;
	} elsif (/./) {
	    my @line = split;
	    my $command = shift @line;
	    eval { CPAN::Shell->$command(@line) };
	    warn $@ if $@;
	    print "\n";
	}
    } continue {
	&cleanup, die if $Signal;
	chdir $cwd;
    }
}

package CPAN::Shell;
use vars qw(@ISA $AUTOLOAD);
@ISA = qw(CPAN::Debug);

# private function ro re-eval this module (handy during development)
sub AUTOLOAD {
    warn "CPAN::Shell doesn't know how to autoload $AUTOLOAD :-(

Nothing Done.
";
}

sub h {
    my($class,$about) = @_;
    if (defined $about) {
	print "Detailed help not yet implemented\n";
    } else {
	print q{
command   arguments   description
a                             authors
b         string              bundles
d         or          display distributions
m         /regex/     info    modules
i         or          about   anything of above
r         none                reinstall recommendations
u                             uninstalled modules

make      modules,    make
test      dists or    make test (implies make)
install   bundles     make install (implies test)
      
reload    index|cpan  load most recent of indices or CPAN.pm                
h                     display this menu
o         various     set and query options
!         perl-code   eval a perl command
q                     quit the shell subroutine

A regular expression has to be between two slashes.
};
    }
}

sub a { print shift->format_result('Author',@_);}
sub b {
    my($self,@which) = @_;
    my($bdir) = $CPAN::META->catdir($CPAN::Config->{'cpan_home'},"Bundle");
    my($dh) = DirHandle->new($bdir); # may fail!
    my($entry);
    for $entry ($dh->read) {
	next if -d $CPAN::META->catdir($bdir,$entry);
	next unless $entry =~ s/\.pm$//;
	$CPAN::META->instance('CPAN::Bundle',"Bundle::$entry");
    }
    print $self->format_result('Bundle',@which);
}
sub d { print shift->format_result('Distribution',@_);}
sub m { print shift->format_result('Module',@_);}

sub i {
    my($self) = shift;
    my(@args) = @_;
    my(@type,$type,@m);
    @type = qw/Author Bundle Distribution Module/;
    @args = '/./' unless @args;
    my(@result);
    for $type (@type) {
	push @result, $self->expand($type,@args);
    }
    my $result =  @result==1 ? $result[0]->as_string : join "", map {$_->as_glimpse} @result;
    $result ||= "No objects found of any type for argument @args\n";
    print $result;
}

sub o {
    my($self,$o_type,@o_what) = @_;
    $o_type ||= "";
    if ($o_type eq 'conf') {
	print q[To set configuration options use the ! escape. E.g.:].qq[\n];
	print q[    !push @{$CPAN::Config->{'urllist'}}, "ftp://another/try/"].qq[\n\n];
	my($k,$v);
	print "CPAN::Config options:\n";
	while (($k,$v) = each %$CPAN::Config) {
	    if (ref $v) {
		printf "    %-18s\n", $k;
		print map {"\t$_\n"} @{$v};
	    } else {
		printf "    %-18s %s\n", $k, $v;
	    }
	}
	print "\n";
    } elsif ($o_type eq 'debug') {
	my(%valid);
	@o_what = () if $o_what[0] =~ /help/i;
	if (@o_what) {
	    while (@o_what) {
		my($what) = shift @o_what;
		if ( exists $CPAN::DEBUG{$what} ) {
		    $CPAN::DEBUG |= $CPAN::DEBUG{$what};
		} elsif ($what =~ /^\d/) {
		    $CPAN::DEBUG = $what;
		} elsif (lc $what eq 'all') {
		    my($max) = 0;
		    for (values %CPAN::DEBUG) {
			$max += $_;
		    }
		    $CPAN::DEBUG = $max;
		} else {
		    for (keys %CPAN::DEBUG) {
			next unless lc($_) eq lc($what);
			$CPAN::DEBUG |= $CPAN::DEBUG{$_};
		    }
		    print "unknown argument $what\n";
		}
	    }
	} else {
	    print "Valid options for debug are ".join(", ",sort(keys %CPAN::DEBUG), 'all').
		" or a number. Completion works on the options. Case is ignored.\n\n";
	}
	if ($CPAN::DEBUG) {
	    print "Options set for debugging:\n";
	    my($k,$v);
	    for $k (sort {$CPAN::DEBUG{$a} <=> $CPAN::DEBUG{$b}} keys %CPAN::DEBUG) {
		$v = $CPAN::DEBUG{$k};
		printf "    %-14s(%s)\n", $k, $v if $v & $CPAN::DEBUG;
	    }
	} else {
	    print "Debugging turned off completely.\n";
	}
    } elsif ($o_type eq 'update') {
	if (@o_what) {
	    if ( $o_what[0] eq 'force' ) {
		$self->{'update_policy'} = 'force';
	    } elsif ($o_what[0] eq 'noforce') {
		$self->{'update_policy'} = 'noforce';
	    } else {
		$o_what[0] = 'help';
	    }
	} else {
	    $o_what[0] = 'help';
	}
	if ($o_what[0] =~ /^h/) {
	    print "Valid options for update are 'force' and 'noforce'.
    Setting to 'force' will reinstall modules even if the installed version
    is up-to-date.\n";
	}
	$CPAN::META->{'update_policy'} ||= 'noforce';
	print "Update policy set to '$CPAN::META->{'update_policy'}'\n";
    } else {
	print qq{
Known options:
  conf    show configuration variables
  debug   set and get debugging options
  update  set and get update options
};
    }
}

sub reload {
    if ($_[1] =~ /cpan/i) {
	CPAN->debug("reloading the whole CPAN.pm") if $CPAN::DEBUG;
	my $fh = IO::File->new($INC{'CPAN.pm'});
	local $/;
	undef $/;
	eval <$fh>;
	warn $@ if $@;
    } elsif ($_[1] =~ /index/) {
	CPAN::Index->force_reload;
    }
}
# u and r are too similar, we should factor out something XXX
sub _u_r_common {
    my($self) = shift @_;
    my($what) = shift @_;
    CPAN->debug("self[$self] what[$what] args[@_]") if $CPAN::DEBUG;
    Carp::croak "Usage: \$obj->_u_r_common($what)" unless defined $what;
    Carp::croak "Usage: \$obj->_u_r_common(a|r|u)" unless $what =~ /^[aru]$/;
    my(@args) = @_;
    @args = '/./' unless @args;
    my(@result,$module,%seen,%need,$headerdone);
    my $sprintf = "%-25s %9s %9s  %s\n";
    for $module ($self->expand('Module',@args)) {
	my $file  = $module->cpan_file;
	next unless defined $file; # ??
	my($latest) = $module->cpan_version || "";
	my($inst_file) = $module->inst_file;
	my($have);
	if ($inst_file){
	    if ($what eq "a") {
		$have = $module->inst_version;
		$have ||= 0;
	    } elsif ($what eq "r") {
		$have = $module->inst_version;
		$have ||= 0;
		local($^W) = 0;
		next if $have >= $latest;
	    } elsif ($what eq "u") {
		next;
	    }
	} else {
	    if ($what eq "a") {
		next;
	    } elsif ($what eq "r") {
		next;
	    } elsif ($what eq "u") {
		$have = "-";
	    }
	}    
	$seen{$file} ||= 0;
	if ($what eq "a") {
	    push @result, sprintf "%s %s\n", $module->id, $have;
	} elsif ($what eq "r") {
	    next if $seen{$file}++;
	} elsif ($what eq "u") {
	    next if $seen{$file}++;
	}
	unless ($headerdone++){
	    print "\n";
	    printf $sprintf, "Package namespace", "installed", "latest", "in CPAN file";
	}
	$latest = substr($latest,0,8) if length($latest) > 8;
	$have = substr($have,0,8) if length($have) > 8;
	printf $sprintf, $module->id, $have, $latest, $file;
	$need{$module->id}++;
	return if $CPAN::Signal; # this is sometimes lengthy
    }
    unless (%need) {
	if ($what eq "u") {
	    print "No modules found for @args\n";
	} elsif ($what eq "r") {
	    print "All modules are up to date for @args\n";
	}
    }
    @result;
}

sub r {
    shift->_u_r_common("r",@_);
}

sub u {
    shift->_u_r_common("u",@_);
}

sub autobundle {
    my($self) = shift;
    my(@bundle) = $self->_u_r_common("a",@_);
    my($todir) = $CPAN::META->catdir($CPAN::Config->{'cpan_home'},"Bundle");
    File::Path::mkpath($todir);
    unless (-d $todir) {
	print "Couldn't mkdir $todir for some reason\n";
	return;
    }
    my($y,$m,$d) =  (localtime)[5,4,3];
    $y+=1900;
    $m++;
    my($c) = 0;
    my($me) = sprintf "Snapshot_%04d_%02d_%02d_%02d", $y, $m, $d, $c;
    my($to) = $CPAN::META->catfile($todir,"$me.pm");
    while (-f $to) {
	$me = sprintf "Snapshot_%04d_%02d_%02d_%02d", $y, $m, $d, ++$c;
	$to = $CPAN::META->catfile($todir,"$me.pm");
    }
    my($fh) = IO::File->new(">$to") or Carp::croak "Can't open >$to: $!";
    $fh->print(
	       "package Bundle::$me;\n\n",
	       "\$VERSION = '0.01';\n\n",
	       "1;\n\n",
	       "__END__\n\n",
	       "=head1 NAME\n\n",
	       "Bundle::$me - Snapshot of installation on ",
	       $Config::Config{'myhostname'},
	       " on ",
	       scalar(localtime),
	       "\n\n=head1 SYNOPSIS\n\n",
	       "perl -MCPAN -e 'install Bundle::$me'\n\n",
	       "=head1 CONTENTS\n\n",
	       join("\n", @bundle),
	       "\n\n=head1 CONFIGURATION\n\n",
	       Config->myconfig,
	       "\n\n=head1 AUTHOR\n\n",
	       "This Bundle has been generated automatically by the autobundle routine in CPAN.pm.\n",
	      );
    $fh->close;
    print "\nWrote bundle file
    $to\n\n";
}

sub bundle {
    shift;
    my(@bundles) = @_;
    my $bundle;
    my @pack = ();
    foreach $bundle (@bundles) {
	my $pack = $bundle;
	$pack =~ s/^(Bundle::)?(.*)/Bundle::$2/;
	push @pack, $CPAN::META->instance('CPAN::Bundle',$pack)->contains;
    }
    @pack;
}

sub bundles {
    my($self) = @_;
    CPAN->debug("self[$self]") if $CPAN::DEBUG;
    sort grep $_->id() =~ /^Bundle::/, $CPAN::META->all('CPAN::Bundle');
}

sub expand {
    shift;
    my($type,@args) = @_;
    my($arg,@m);
    for $arg (@args) {
	my $regex;
	if ($arg =~ m|^/(.*)/$|) {
	    $regex = $1;
	}
	my $class = "CPAN::$type";
	my $obj;
	if (defined $regex) {
	    for $obj ( sort {$a->id cmp $b->id} $CPAN::META->all($class)) {
		push @m, $obj if $obj->id =~ /$regex/i or $obj->can('name') && $obj->name  =~ /$regex/i;
	    }
	} else {
	    my($xarg) = $arg;
	    if ( $type eq 'Bundle' ) {
		$xarg =~ s/^(Bundle::)?(.*)/Bundle::$2/;
	    }
	    if ($CPAN::META->exists($class,$xarg)) {
		$obj = $CPAN::META->instance($class,$xarg);
	    } elsif ($obj = $CPAN::META->exists($class,$arg)) {
		$obj = $CPAN::META->instance($class,$arg);
	    } else {
		next;
	    }
	    push @m, $obj;
	}
    }
    return @m;
}

sub format_result {
    my($self)=shift;
    my($type,@args) = @_;
    @args = '/./' unless @args;
    my(@result) = $self->expand($type,@args);
    my $result =  @result==1 ? $result[0]->as_string : join "", map {$_->as_glimpse} @result;
    $result ||= "No objects of type $type found for argument @args\n";
    $result;
}

sub rematein {
    shift;
    my($meth,@some) = @_;
    CPAN->debug("meth[$meth] some[@some]") if $CPAN::DEBUG;
    my($s,@s);
    foreach $s (@some) {
	my $obj;
	if (ref $s) {
	    $obj = $s;
	} elsif ($s =~ m|/|) { # looks like a file
	    $obj = $CPAN::META->instance('CPAN::Distribution',$s);
	} elsif ($s =~ m|^Bundle::|) {
	    $obj = $CPAN::META->instance('CPAN::Bundle',$s);
	} else {
	    $obj = $CPAN::META->instance('CPAN::Module',$s);
	}
	if (ref $obj) {
	    CPAN->debug(qq{meth[$meth] obj[$obj] as_string\[}.$obj->as_string.qq{\]}) if $CPAN::DEBUG;
	    $obj->$meth();
	    CPAN->debug(qq{meth[$meth] obj[$obj] as_string\[}.$obj->as_string.qq{\]}) if $CPAN::DEBUG;
	} else {
	    print "Warning: Cannot $meth $s [obj $obj], don't know what it is\n";
	}
    }
}

sub readme  { shift->rematein('readme',@_); }
sub make    { shift->rematein('make',@_); }
sub test    { shift->rematein('test',@_); }
sub install { shift->rematein('install',@_); }

package CPAN::FTP;
use vars qw($Ua @ISA);
@ISA = qw(CPAN::Debug);

sub ftp_get {
    my($class,$host,$dir,$file,$target) = @_;
    $class->debug(
		       qq[Going to fetch file [$file] from dir [$dir]
	on host [$host] as local [$target]\n]
		      ) if $CPAN::DEBUG;
    my $ftp = Net::FTP->new($host);
    $ftp->debug(1) if $CPAN::DEBUG{'FTP'} & $CPAN::DEBUG;
    $class->debug(qq[Going to ->login("anonymous","$Config::Config{cf_email}")\n]);
    unless ( $ftp->login("anonymous",$Config::Config{cf_email}) ){
	warn "Couldn't login on $host";
	return;
    }
    # print qq[Going to ->cwd("$dir")\n];
    unless ( $ftp->cwd($dir) ){
	warn "Couldn't cwd $dir";
	return;
    }
    $ftp->binary;
    print qq[Going to ->get("$file","$target")\n];
    unless ( $ftp->get($file,$target) ){
	warn "Couldn't fetch $file from $host";
	return;
    }
    $ftp->quit;
}

sub localize {
    my($self,$file,$aslocal,$force) = @_;
    $force ||= 0;
    Carp::croak "Usage: ->localize(cpan_file,as_local_file[,$force])" unless defined $aslocal;
    $self->debug("file [$file] aslocal [$aslocal]") if $CPAN::DEBUG;

    return $aslocal if -f $aslocal && -r _ && ! $force;

    my($aslocal_dir) = File::Basename::dirname($aslocal);
    File::Path::mkpath($aslocal_dir);
    print STDERR qq{Warning: You are not allowed to write into directory "$aslocal_dir".
    I\'ll continue, but if you face any problems, they may be due
    to insufficient permissions.\n} unless -w $aslocal_dir;

    # Inheritance is not easier to manage than a few if/else branches
    if ($CPAN::META->hasLWP) {
	require LWP::UserAgent;
 	unless ($Ua) {
	    $Ua = new LWP::UserAgent;
	    $Ua->proxy('ftp',  $ENV{'ftp_proxy'})  if defined $ENV{'ftp_proxy'};
	    $Ua->proxy('http', $ENV{'http_proxy'}) if defined $ENV{'http_proxy'};
	    $Ua->no_proxy($ENV{'noproxy'})         if defined $ENV{'no_proxy'};
	}
    }

    # Try the list of urls for each single object. We keep a record
    # where we did get a file from
    for (0..$#{$CPAN::Config->{urllist}}) {
	my $url = $CPAN::Config->{urllist}[$_] . $file;
	$self->debug("for $url") if $CPAN::DEBUG;
	if ($url =~ /^file:/) {
	    my $l;
	    if ($CPAN::META->hasLWP) {
		require URI::URL;
		my $u = new URI::URL $url;
		$l = $u->path;
	    } else { # works only on Unix
		($l = $url) =~ s/^file://;
	    }
	    return $l if -f $l && -r _;
	}

	if ($CPAN::META->hasLWP) {
	    print "Fetching $url\n";
	    my $res = $Ua->mirror($url, $aslocal);
	    if ($res->is_success) {
		return $aslocal;
	    }
	} elsif ($url =~ m|^ftp://(.*?)/(.*)/(.*)|) {
	    unless ($CPAN::META->hasFTP) {
		warn "Can't access URL $url without module Net::FTP";
		next;
	    }
	    my($host,$dir,$getfile) = ($1,$2,$3);
	    $dir =~ s|/+|/|g;
	    print "Going to fetch file [$getfile] from dir [$dir] on host [$host] as local [$aslocal]\n";

	    #### This was the bug where I contacted Graham and got so strange error messages
	    #### ftp_get($host,$dir,$getfile,$aslocal) && return $aslocal;
	    CPAN::FTP->ftp_get($host,$dir,$getfile,$aslocal) && return $aslocal;
	}
    }
    Carp::croak("Cannot fetch $file from anywhere");
}

package CPAN::Complete;
use vars qw(@ISA);
@ISA = qw(CPAN::Debug);

sub complete {
    my($word,$line,$pos) = @_;
    $word ||= "";
    $line ||= "";
    $pos ||= 0;
    CPAN->debug("word [$word] line[$line] pos[$pos]") if $CPAN::DEBUG;
    $line =~ s/^\s*//;
    return
	$pos == 0 ? grep /^$word/, sort qw(! a b d h i m o q r u autobundle make test install reload) :
	    $line !~ /^[\!abdhimorut]/ ? () :
	    $line =~ /^a\s/ ? completex('CPAN::Author',$word) :
	    $line =~ /^b\s/ ? completex('CPAN::Bundle',$word) :
	    $line =~ /^d\s/ ? completex('CPAN::Distribution',$word) :
	    $line =~ /^([mru]\s|(make|test|install)\s)/ ?
		(completex('CPAN::Module',$word),completex('CPAN::Bundle',$word)) :
	    $line =~ /^i\s/ ? complete_any($word) :
	    $line =~ /^reload\s/ ? complete_reload($word,$line,$pos) :
	    $line =~ /^o\s/ ? complete_option($word,$line,$pos) : ();
}

sub completex { 
    my($class, $word) = @_;
    grep /^\Q$word\E/, map { $_->id } $CPAN::META->all($class);
}

sub complete_any {
    my($word) = shift;
    return (
	    completex('CPAN::Author',$word),
	    completex('CPAN::Bundle',$word),
	    completex('CPAN::Distribution',$word),
	    completex('CPAN::Module',$word),
	   );
}

sub complete_reload {
    my($word,$line,$pos) = @_;
    $word ||= "";
    my(@words) = split " ", $line;
    CPAN->debug("word[$word] line[$line] pos[$pos]") if $CPAN::DEBUG;
    my(@ok) = qw(cpan index);
    return @ok if @words==1;
    return grep /^\Q$word\E/, @ok if @words==2 && $word;
}

sub complete_option {
    my($word,$line,$pos) = @_;
    $word ||= "";
    my(@words) = split " ", $line;
    CPAN->debug("word[$word] line[$line] pos[$pos]") if $CPAN::DEBUG;
    my(@ok) = qw(conf debug update);
    return @ok if @words==1;
    return grep /^\Q$word\E/, @ok if @words==2 && $word;
    if (0) {
    } elsif ($words[1] eq 'index') {
	return ();
    } elsif ($words[1] eq 'conf') {
	return ();
    } elsif ($words[1] eq 'debug') {
	return sort grep /^\Q$word\E/, sort keys %CPAN::DEBUG, 'all';
    } elsif ($words[1] eq 'update') {
	return sort grep /^\Q$word\E/, 'force', 'noforce';
    }
    
}

package CPAN::Index;
use vars qw($last_time @ISA);
@ISA = qw(CPAN::Debug);
$last_time ||= 0;

sub force_reload {
    my($class) = @_;
    $CPAN::Index::last_time = 0;
    $class->reload(1);
}

sub reload {
    my($cl,$force) = @_;
    my $time = time;

    # XXX check if a newer one is available. (We currently read it from time to time)
    return if $last_time + $CPAN::Config->{cache_expire}*86400 > $time;
    $last_time = $time;

    $cl->read_authindex($cl->reload_x("authors/01mailrc.txt.gz","01mailrc.gz",$force));
    return if $CPAN::Signal; # this is sometimes lengthy
    $cl->read_modpacks($cl->reload_x("modules/02packages.details.txt.gz","02packag.gz",$force));
    return if $CPAN::Signal; # this is sometimes lengthy
    $cl->read_modlist($cl->reload_x("modules/03modlist.data.gz","03mlist.gz",$force));
}

sub reload_x {
    my($cl,$wanted,$localname,$force) = @_;
    $force ||= 0;
    my $abs_wanted = CPAN->catfile($CPAN::Config->{'keep_source_where'},$localname);
    if (-f $abs_wanted && -M $abs_wanted < $CPAN::Config->{'cache_expire'} && !$force) {
	my($s) = $CPAN::Config->{'cache_expire'} != 1;
	$cl->debug(qq{$abs_wanted younger than $CPAN::Config->{'cache_expire'} day$s. I\'ll use that.\n});
	return $abs_wanted;
    }
    return CPAN::FTP->localize($wanted,$abs_wanted,$force);
}

sub read_authindex {
    my($cl,$index_target) = @_;
    my $pipe = "$CPAN::Config->{gzip} --decompress --stdout $index_target";
    warn "Going to read $index_target\n";
    my $fh = IO::File->new("$pipe|");
    while (<$fh>) {
	chomp;
	my($userid,$fullname,$email) = /alias\s+(\S+)\s+\"([^\"\<]+)\s+<([^\>]+)\>\"/;
	next unless $userid && $fullname && $email;

	# instantiate an author object
 	my $userobj = $CPAN::META->instance('CPAN::Author',$userid);
	$userobj->set('FULLNAME' => $fullname, 'EMAIL' => $email);
	return if $CPAN::Signal;
    }
    $fh->close;
    $? and Carp::croak "FAILED $pipe: exit status [$?]";
}

sub read_modpacks {
    my($cl,$index_target) = @_;
    my $pipe = "$CPAN::Config->{gzip} --decompress --stdout $index_target";
    warn "Going to read $index_target\n";
    my $fh = IO::File->new("$pipe|");
    while (<$fh>) {
	next if 1../^\s*$/;
	next unless /\s\+/; # we ignore package names that have no
                            # corresponding file (i.e. which have no
                            # '+' sign in column 2)
	chomp;
	my($mod,$version,$dist) = split;
	$version =~ s/^\+//;

	# if it as a bundle, instatiate a bundle object
	my($bundle) = $mod =~ /^Bundle::(.*)/;
	$version = "n/a" if $mod =~ s/(.+::.+::).+/$1*/; # replace the third level with a star
	
	my($id);
	if ($bundle){
	    $id =  $CPAN::META->instance('CPAN::Bundle',$mod);
	    $id->set('CPAN_VERSION' => $version, 'CPAN_FILE' => $dist);
	} elsif ($CPAN::META->exists('CPAN::Module',$mod)) {
	    next;
	} else {
	    # instantiate a module object
	    $id = $CPAN::META->instance('CPAN::Module',$mod);
	    $id->set('CPAN_VERSION' => $version, 'CPAN_FILE' => $dist);
	}

	# determine the author
	my($userid) = $dist =~ /([^\/]+)/;
	$id->set('CPAN_USERID' => $userid) if $userid =~ /\w/;

	# instantiate a distribution object
	unless ($CPAN::META->exists('CPAN::Distribution',$dist)) {
	    $CPAN::META->instance(
				  'CPAN::Distribution' => $dist
				 )->set(
					'CPAN_USERID' => $userid
				       )
				     if $userid =~ /\w/;
	}

	return if $CPAN::Signal;
    }
    $fh->close;
    $? and Carp::croak "FAILED $pipe: exit status [$?]";
}

sub read_modlist {
    my($cl,$index_target) = @_;
    my $pipe = "$CPAN::Config->{gzip} --decompress --stdout $index_target";
    warn "Going to read $index_target\n";
    my $fh = IO::File->new("$pipe|");
    my $eval = "";
    while (<$fh>) {
	next if 1../^\s*$/;
	$eval .= $_;
	return if $CPAN::Signal;
    }
    local($^W) = 0;
    eval $eval;
    Carp::confess($@) if $@;
    return if $CPAN::Signal;
    my $result = CPAN::Modulelist->data;
    for (keys %$result) {
	my $obj = $CPAN::META->instance(CPAN::Module,$_);
	$obj->set(%{$result->{$_}});
	return if $CPAN::Signal;
    }
}

package CPAN::InfoObj;
use vars qw(@ISA);
@ISA = qw(CPAN::Debug);

sub new { my $this = bless {}, shift; %$this = @_; $this }

sub set {
    my($self,%att) = @_;
    my(%oldatt) = %$self;
    %$self = (%oldatt, %att);
}

sub id { shift->{'ID'} }

sub as_glimpse {
    my($self) = @_;
    my(@m);
    my $class = ref($self);
    $class =~ s/^CPAN:://;
    push @m, sprintf "%-15s %s\n", $class, $self->{ID};
    join "", @m;
}

sub as_string {
    my($self) = @_;
    my(@m);
    my $class = ref($self);
    $class =~ s/^CPAN:://;
    push @m, $class, " id = $self->{ID}\n";
    for (sort keys %$self) {
	next if $_ eq 'ID';
	my $extra = "";
	$_ eq "CPAN_USERID" and $extra = " (".$self->author.")";
	if (ref $self->{$_}) { # Language? XXX
	    push @m, sprintf "    %-12s %s%s\n", $_, "@{$self->{$_}}", $extra;
	} else {
	    push @m, sprintf "    %-12s %s%s\n", $_, $self->{$_}, $extra;
	}
    }
    join "", @m, "\n";
}

sub author {
    my($self) = @_;
    $CPAN::META->instance(CPAN::Author,$self->{CPAN_USERID})->fullname;
}

package CPAN::Author;
use vars qw(@ISA);
@ISA = qw(CPAN::Debug CPAN::InfoObj);

sub as_glimpse {
    my($self) = @_;
    my(@m);
    my $class = ref($self);
    $class =~ s/^CPAN:://;
    push @m, sprintf "%-15s %s (%s)\n", $class, $self->{ID}, $self->fullname;
    join "", @m;
}

sub fullname { shift->{'FULLNAME'} }
*name = \&fullname;
sub email    { shift->{'EMAIL'} }

package CPAN::Distribution;
use vars qw(@ISA);
@ISA = qw(CPAN::Debug CPAN::InfoObj);

sub called_for {
    my($self,$id) = @_;
    $self->{'CALLED_FOR'} = $id if defined $id;
    return $self->{'CALLED_FOR'};
}

sub get {
    my($self) = @_;
  EXCUSE: {
	my @e;
	exists $self->{'build_dir'} and push @e, "Unwrapped into directory $self->{'build_dir'}";
	print join "", map {"  $_\n"} @e and return if @e;
    }
    my($local_file);
    my($local_wanted) =
	 CPAN->catfile(
			$CPAN::Config->{keep_source_where},
			"authors",
			"id",
			split("/",$self->{ID})
		       );

    $self->debug("Doing localize") if $CPAN::DEBUG;
    $local_file = CPAN::FTP->localize("authors/id/$self->{ID}", $local_wanted);
    $self->{localfile} = $local_file;
    my $builddir = $CPAN::META->{cachemgr}->dir;
    $self->debug("doing chdir $builddir") if $CPAN::DEBUG;
    chdir $builddir or Carp::croak("Couldn't chdir $builddir: $!");
    my $packagedir;

    $self->debug("local_file[$local_file]") if $CPAN::DEBUG;
    if ($local_file =~ /(\.tar\.(gz|Z)|\.tgz|\.zip)$/i){
	$self->debug("Removing tmp") if $CPAN::DEBUG;
	File::Path::rmtree("tmp");
	mkdir "tmp", 0777 or Carp::croak "Couldn't mkdir tmp: $!";
	chdir "tmp";
	$self->debug("Changed directory to tmp") if $CPAN::DEBUG;
	if ($local_file =~ /z$/i){
	    $self->{archived} = "tar";
	    if (system("$CPAN::Config->{gzip} --decompress --stdout $local_file | $CPAN::Config->{tar} xvf -")==0) {
		$self->{unwrapped} = "YES";
	    } else {
		$self->{unwrapped} = "NO";
	    }
	} elsif ($local_file =~ /zip$/i) {
	    $self->{archived} = "zip";
	    if (system("$CPAN::Config->{unzip} $local_file")==0) {
		$self->{unwrapped} = "YES";
	    } else {
		$self->{unwrapped} = "NO";
	    }
	}
	# Let's check if the package has his own directory.
	opendir DIR, "." or Carp::croak("Weird: couldn't opendir .: $!");
	my @readdir = grep $_ !~ /^\.\.?$/, readdir DIR; ### MAC??
	closedir DIR;
	my ($distdir,$packagedir);
	if (@readdir == 1 && -d $readdir[0]) {
	    $distdir = $readdir[0];
	    $packagedir = $CPAN::META->catdir($builddir,$distdir);
	    -d $packagedir and print "Removing previously used CPAN build directory\n";
	    File::Path::rmtree($packagedir);
	    rename($distdir,$packagedir) or Carp::confess("Couldn't rename $distdir to $packagedir");
	} else {
	    my $pragmatic_dir = $self->{'CPAN_USERID'} . '000';
	    $pragmatic_dir =~ s/\W_//g;
	    $pragmatic_dir++ while -d "../$pragmatic_dir";
	    $packagedir = $CPAN::META->catdir($builddir,$pragmatic_dir);
	    File::Path::mkpath($packagedir);
	    my($f);
	    for $f (@readdir) { # is already without "." and ".."
		my $to = $CPAN::META->catdir($packagedir,$f);
		rename($f,$to) or Carp::confess("Couldn't rename $f to $to");
	    }
	}
	$self->{'build_dir'} = $packagedir;

	chdir "..";
	$self->debug("Changed directory to .. (self is $self [".$self->as_string."])") if $CPAN::DEBUG;
	File::Path::rmtree("tmp");
	if ($CPAN::Config->{keep_source_where} =~ /^no/i ){
	    print "Going to unlink $local_file\n";
	    unlink $local_file or Carp::carp "Couldn't unlink $local_file";
	}
	my($makefilepl) = $CPAN::META->catfile($packagedir,"Makefile.PL");
	unless (-f $makefilepl) {
	    my($configure) = $CPAN::META->catfile($packagedir,"Configure");
	    if (-f $configure) {
		# do we have anything to do?
		$self->{'configure'} = $configure;
	    } else {
		my $fh = IO::File->new(">$makefilepl") or Carp::croak("Could not open >$makefilepl");
		my $cf = $self->called_for || "unknown";
		$fh->print(qq{
# This Makefile.PL has been autogenerated by the module CPAN.pm
# Autogenerated on: }.scalar localtime().qq{
		    use ExtUtils::MakeMaker;
		    WriteMakefile(NAME => q[$cf]);
});
		print qq{Package comes without Makefile.PL.\n}.
		    qq{  Writing one on our own (calling it $cf)\n};
	    }
	}
    } else {
	$self->{archived} = "NO";
    }
    return $self;
}

sub new {
    my($class,%att) = @_;

    $CPAN::META->{cachemgr} ||= CPAN::CacheMgr->new();

    my $this = { %att };
    return bless $this, $class;
}

sub readme {
    my($self) = @_;
    print "Readme not yet implemented (says ".$self->id.")\n";
}

sub verifyMD5 {
    my($self) = @_;
  EXCUSE: {
	my @e;
	$self->{MD5_STATUS} and push @e, "MD5 Checksum was ok";
	print join "", map {"  $_\n"} @e and return if @e;
    }
    my($local_file,$cksum);
    my(@local) = split("/",$self->{ID});
    my($basename) = pop @local;
    push @local, "CHECKSUMS";
    my($local_wanted) =
	 CPAN->catfile(
			$CPAN::Config->{keep_source_where},
			"authors",
			"id",
			@local
		       );
    local($") = "/";
    $local_file = CPAN::FTP->localize("authors/id/@local", $local_wanted, 'force>:-{');
    my($checksum_pipe);
    if ($local_file) {
	$checksum_pipe = $local_file;
    } else {
	$local[-1] .= ".gz";
	$local_file = CPAN::FTP->localize("authors/id/@local", $local_wanted, 'force>:-{');
	$checksum_pipe = "$CPAN::Config->{gzip} --decompress --stdout $local_file |"
    }
    my $fh = new IO::File;
    local($/)=undef;
    if (open $fh, $local_file){
	eval <$fh>;
	close $fh;
	if ($cksum->{$basename}->{md5}) {
	    $self->debug("Found checksum for $basename: $cksum->{$basename}->{md5}\n") if $CPAN::DEBUG;
	    my $file = $self->{localfile};
	    my $pipe = "$CPAN::Config->{gzip} --decompress --stdout $self->{localfile}|";
	    if (
		open($fh, $file) && $self->eq_MD5($fh,$cksum->{$basename}->{md5})
		or
		open($fh, $pipe) && $self->eq_MD5($fh,$cksum->{$basename}->{'md5-ungz'})
	       ){
		print "Checksum for $file ok\n";
		return $self->{MD5_STATUS}="OK";
	    } else {
		die join(
			 "",
			 "\nChecksum mismatch for distribution file. Please investigate.\n\n",
			 $self->as_string,
			 $CPAN::META->instance('CPAN::Author',$self->{CPAN_USERID})->as_string,
			 "Please contact the author or your CPAN site admin"
			);
	    }
	    close $fh if fileno($fh);
	} else {
	    warn "Could not find the checksum in $local_file";
	}
    } else {
	warn "Could not read the CHECKSUMS file $local_file";
    }
}

sub eq_MD5 {
    my($self,$fh,$expectMD5) = @_;
    my $md5 = new MD5;
    $md5->addfile($fh);
    my $hexdigest = $md5->hexdigest;
    $hexdigest eq $expectMD5;
}

sub make {
    my($self) = @_;
    $self->debug("CPAN::Distribution::make for [".$self->id."]") if $CPAN::DEBUG;
    print "Running make\n";
    $self->get;
    if ($CPAN::META->hasMD5) {
	$self->verifyMD5;
    }
    EXCUSE: {
	  my @e;
	  $self->{archived} eq "NO" and push @e, "Is neither a tar nor a zip archive.";
	  $self->{unwrapped} eq "NO"   and push @e, "had problems unarchiving. Please build manually";
	  exists $self->{writemakefile} && $self->{writemakefile} eq "NO" and push @e, "Had some problem writing Makefile";
	  defined $self->{'make'} and push @e, "Has already been processed within this session";
	  print join "", map {"  $_\n"} @e and return if @e;
     }
    print "\n  CPAN: Going to build ".$self->id."\n\n";
    my $builddir = $self->dir;
    chdir $builddir or Carp::croak("Couldn't chdir $builddir: $!");
    $self->debug("Changed directory to $builddir") if $CPAN::DEBUG;

    my $system;
    if ($self->{'configure'}) {
	$system = $self->{'configure'};
    } else {
	$system = "$^X Makefile.PL $CPAN::Config->{makepl_arg}";
    }
    if (system($system)!=0) {
	 $self->{writemakefile} = "NO";
	 return;
    }
    $self->{writemakefile} = "YES";
    return if $CPAN::Signal;
    $system = join " ", $CPAN::Config->{'make'}, $CPAN::Config->{make_arg};
    if (system($system)==0) {
	 print "  $system -- OK\n";
	 $self->{'make'} = "YES";
    } else {
	 $self->{writemakefile} = "YES";
	 $self->{'make'} = "NO";
	 print "  $system -- NOT OK\n";
    }
}

sub test {
    my($self) = @_;
    $self->make;
    return if $CPAN::Signal;
    print "Running make test\n";
    EXCUSE: {
	  my @e;
	  exists $self->{'make'} or push @e, "Make had some problems, maybe interrupted? Won't test";
	  exists $self->{'make'} and $self->{'make'} eq 'NO' and push @e, "Oops, make had returned bad status";
	  exists $self->{'build_dir'} or push @e, "Has no own directory";
	  print join "", map {"  $_\n"} @e and return if @e;
     }
    chdir $self->{'build_dir'} or Carp::croak("Couldn't chdir to $self->{'build_dir'}");
    $self->debug("Changed directory to $self->{'build_dir'}") if $CPAN::DEBUG;
    my $system = join " ", $CPAN::Config->{'make'}, "test";
    if (system($system)==0) {
	 print "  $system -- OK\n";
	 $self->{'make_test'} = "YES";
    } else {
	 $self->{'make_test'} = "NO";
	 print "  $system -- NOT OK\n";
    }
}

sub install {
    my($self) = @_;
    $self->test;
    return if $CPAN::Signal;
    print "Running make install\n";
    EXCUSE: {
	  my @e;
	  exists $self->{'make'} or push @e, "Make had some problems, maybe interrupted? Won't install";
	  exists $self->{'make'} and $self->{'make'} eq 'NO' and push @e, "Oops, make had returned bad status";
	  exists $self->{'install'} and push @e, $self->{'install'} eq "YES" ? "Already done" : "Already tried without success";
	  exists $self->{'build_dir'} or push @e, "Has no own directory";
	  print join "", map {"  $_\n"} @e and return if @e;
     }
    chdir $self->{'build_dir'} or Carp::croak("Couldn't chdir to $self->{'build_dir'}");
    $self->debug("Changed directory to $self->{'build_dir'}") if $CPAN::DEBUG;
    my $system = join " ", $CPAN::Config->{'make'}, "install", $CPAN::Config->{make_install_arg};
    if (system($system)==0) {
	 print "  $system -- OK\n";
	 $self->{'install'} = "YES";
    } else {
	 $self->{'install'} = "NO";
	 print "  $system -- NOT OK\n";
    }
}

sub dir {
    shift->{'build_dir'};
}

package CPAN::Bundle;
use vars qw(@ISA);
@ISA = qw(CPAN::Debug CPAN::InfoObj CPAN::Module);

sub as_string {
    my($self) = @_;
    $self->contains;
    return $self->SUPER::as_string;
}

sub contains {
    my($self) = @_;
    my($parsefile) = $self->inst_file;
    unless ($parsefile) {
	# Try to get at it in the cpan directory
	$self->debug("no parsefile") if $CPAN::DEBUG;
	my $dist = $CPAN::META->instance('CPAN::Distribution',$self->{'CPAN_FILE'});
	$self->debug($dist->as_string) if $CPAN::DEBUG;
	$dist->get;
	$self->debug($dist->as_string) if $CPAN::DEBUG;
	my($todir) = $CPAN::META->catdir($CPAN::Config->{'cpan_home'},"Bundle");
	File::Path::mkpath($todir);
	my($me,$from,$to);
	($me = $self->id) =~ s/.*://;
	$from = $CPAN::META->catfile($dist->{'build_dir'},"$me.pm");
	$to = $CPAN::META->catfile($todir,"$me.pm");
	rename($from, $to) or Carp::croak("Couldn't rename $from to $to: $!");
	$parsefile = $to;
    }
    my @result;
    my $fh = new IO::File;
    local $/ = "\n";
    open($fh,$parsefile) or die "Could not open '$parsefile': $!";
    my $inpod = 0;
    while (<$fh>) {
	$inpod = /^=(?!head1\s+CONTENTS)/ ? 0 : /^=head1\s+CONTENTS/ ? 1 : $inpod;
	next unless $inpod;
	next if /^=/;
	next if /^\s+$/;
	chomp;
	push @result, (split " ", $_, 2)[0];
    }
    close $fh;
    delete $self->{STATUS};
    $self->{CONTAINS} = [@result];
    @result;
}

sub inst_file {
    my($self) = @_;
    my($me,$inst_file);
    ($me = $self->id) =~ s/.*://;
    $inst_file = $CPAN::META->catfile($CPAN::Config->{'cpan_home'},"Bundle", "$me.pm");
    return $self->{'INST_FILE'} = $inst_file if -f $inst_file;
    $inst_file = $self->SUPER::inst_file;
    return $self->{'INST_FILE'} = $inst_file if -f $inst_file;
    return $self->{'INST_FILE'}; # even if undefined?
}

sub rematein {
    my($self,$meth) = @_;
    $self->debug("self[$self] meth[$meth]") if $CPAN::DEBUG;
    my($s);
    for $s ($self->contains) {
	$CPAN::META->instance('CPAN::Module',$s)->$meth();
    }
}

sub install { shift->rematein('install',@_); }
sub test    { shift->rematein('test',@_); }
sub make    { shift->rematein('make',@_); }
sub readme  {
    my($self) = @_;
    my($file) = $self->cpan_file or print("No File found for bundle ", $self->id, "\n"), return;
    $self->debug("self[$self] file[$file]") if $CPAN::DEBUG;
    $CPAN::META->instance('CPAN::Distribution',$file)->readme;
#    CPAN::FTP->localize("authors/id/$file",$index_wanted); # XXX
}

package CPAN::Module;
use vars qw(@ISA);
@ISA = qw(CPAN::Debug CPAN::InfoObj);

sub as_glimpse {
    my($self) = @_;
    my(@m);
    my $class = ref($self);
    $class =~ s/^CPAN:://;
    push @m, sprintf "%-15s %-15s (%s)\n", $class, $self->{ID}, $self->cpan_file;
    join "", @m;
}

sub as_string {
    my($self) = @_;
    my(@m);
    my $class = ref($self);
    $class =~ s/^CPAN:://;
    local($^W) = 0;
    push @m, $class, " id = $self->{ID}\n";
    my $sprintf = "    %-12s %s\n";
    push @m, sprintf $sprintf, 'DESCRIPTION', $self->{description} if $self->{description};
    my $sprintf2 = "    %-12s %s (%s)\n";
    my($userid);
    if ($userid = $self->{'CPAN_USERID'} || $self->{'userid'}){
	push @m, sprintf(
			 $sprintf2,
			 'CPAN_USERID',
			 $userid,
			 $CPAN::META->instance(CPAN::Author,$userid)->fullname
			)
    }
    push @m, sprintf $sprintf, 'CPAN_VERSION', $self->{CPAN_VERSION} if $self->{CPAN_VERSION};
    push @m, sprintf $sprintf, 'CPAN_FILE', $self->{CPAN_FILE} if $self->{CPAN_FILE};
    my $sprintf3 = "    %-12s %1s%1s%1s%1s (%s,%s,%s,%s)\n";
    my(%statd,%stats,%statl,%stati);
    @statd{qw,? i c a b R M S,} = qw,unknown idea pre-alpha alpha beta released mature standard,;
    @stats{qw,? m d u n,}       = qw,unknown mailing-list developer comp.lang.perl.* none,;
    @statl{qw,? p c + o,}       = qw,unknown perl C C++ other,;
    @stati{qw,? f r O,}         = qw,unknown functions references+ties object-oriented,;
    $statd{' '} = 'unknown';
    $stats{' '} = 'unknown';
    $statl{' '} = 'unknown';
    $stati{' '} = 'unknown';
    push @m, sprintf(
		     $sprintf3,
		     'DSLI_STATUS',
		     $self->{statd},
		     $self->{stats},
		     $self->{statl},
		     $self->{stati},
		     $statd{$self->{statd}},
		     $stats{$self->{stats}},
		     $statl{$self->{statl}},
		     $stati{$self->{stati}}
		    ) if $self->{statd};
    my $local_file = $self->inst_file;
    if ($local_file && ! exists $self->{MANPAGE}) {
	my $fh = IO::File->new($local_file) or Carp::croak("Couldn't open $local_file: $!");
	my $inpod = 0;
	my(@result);
	local $/ = "\n";
	while (<$fh>) {
	    $inpod = /^=(?!head1\s+NAME)/ ? 0 : /^=head1\s+NAME/ ? 1 : $inpod;
	    next unless $inpod;
	    next if /^=/;
	    next if /^\s+$/;
	    chomp;
	    push @result, $_;
	}
	close $fh;
	$self->{MANPAGE} = join " ", @result;
    }
    push @m, sprintf $sprintf, 'MANPAGE', $self->{MANPAGE} if $self->{MANPAGE};
    push @m, sprintf $sprintf, 'INST_FILE', $local_file || "(not installed)";
    push @m, sprintf $sprintf, 'INST_VERSION', $self->inst_version if $local_file;
    join "", @m, "\n";
}

sub cpan_file    {
    my $self = shift;
    unless (defined $self->{'CPAN_FILE'}) {
	CPAN::Index->reload;
    }
    defined $self->{'CPAN_FILE'} ? $self->{'CPAN_FILE'} :
	defined $self->{'userid'} ? "Contact Author ".$self->{'userid'}."=".$CPAN::META->instance(CPAN::Author,$self->{'userid'})->fullname : "N/A";
}

*name = \&cpan_file;

sub cpan_version { shift->{'CPAN_VERSION'} }

sub rematein {
    my($self,$meth) = @_;
    $self->debug("for [".$self->id."]") if $CPAN::DEBUG;
    my $cpan_file = $self->cpan_file;
    my $pack = $CPAN::META->instance('CPAN::Distribution',$self->cpan_file);
    $pack->called_for($self->id);
    $pack->$meth();
}

sub readme { shift->rematein('readme') }
sub make { shift->rematein('make') }
sub test { shift->rematein('test') }
sub install { 
    my($self) = @_;
    my($doit) = 0;
    $CPAN::META->{'update_policy'} ||= 'noforce';
    if ($CPAN::META->{'update_policy'} eq 'force') {
	$doit = 1;
    } else {
	my($latest) = $self->cpan_version;
	$latest ||= 0;
	my($inst_file) = $self->inst_file;
	my($have) = 0;
	if (defined $inst_file) {
	    $have = $self->inst_version;
	    $have ||= 0;
	}
	if ($have >= $latest) {
	    print $self->id, " up-to-date.\n";
	} else {
	    $doit = 1;
	}
    }
    $self->rematein('install') if $doit;
}

sub inst_file {
    my($self) = @_;
    my($dir,@packpath);
    @packpath = split /::/, $self->{ID};
    $packpath[-1] .= ".pm";
    foreach $dir (@INC) {
	my $pmfile = CPAN->catfile($dir,@packpath);
	if (-f $pmfile){
	    return $pmfile;
	}
    }
}

sub inst_version {
    my($self) = @_;
    my $parsefile = $self->inst_file or return 0;
    MY->parse_version($parsefile);
}

package CPAN::CacheMgr;
use vars qw($Du @ISA);
@ISA=qw(CPAN::Debug CPAN::InfoObj);
use File::Find;

sub as_string {
    eval { require Data::Dumper };
    if ($@) {
	return shift->SUPER::as_string;
    } else {
	return Data::Dumper::Dumper(shift);
    }
}

sub cachesize {
    shift->{DU};
}

# sub check {
#     my($self,@dirs) = @_;
#     return unless -d $self->{ID};
#     my $dir;
#     @dirs = $self->dirs unless @dirs;
#     for $dir (@dirs) {
# 	  $self->disk_usage($dir);
#     }
# }

sub clean_cache {
    my $self = shift;
    my $dir;
    while ($self->{DU} > $self->{'MAX'} and $dir = shift @{$self->{FIFO}}) {
	$self->force_clean_cache($dir);
    }
    $self->debug("leaving clean_cache with $self->{DU}") if $CPAN::DEBUG;
}

sub dir {
    shift->{ID};
}

sub entries {
    my($self,$dir) = @_;
    $dir ||= $self->{ID};
    my($cwd) = Cwd::cwd();
    chdir $dir or Carp::croak("Can't chdir to $dir: $!");
    my $dh = DirHandle->new(".") or Carp::croak("Couldn't opendir $dir: $!");
    my(@entries);
    for ($dh->read) {
	next if $_ eq "." || $_ eq "..";
	if (-f $_) {
	    push @entries, $CPAN::META->catfile($dir,$_);
	} elsif (-d _) {
	    push @entries, $CPAN::META->catdir($dir,$_);
	} else {
	    print STDERR "Warning: weird direntry in $dir: $_\n";
	}
    }
    chdir $cwd or Carp::croak("Can't chdir to $cwd: $!");
    sort {-M $b <=> -M $a} @entries;
}

sub disk_usage {
    my($self,$dir) = @_;
    if (not defined $dir or $dir eq "") {
	$self->debug("Cannot determine disk usage for some reason") if $CPAN::DEBUG;
	return;
    }
    return if defined $self->{SIZE}{$dir};
    local($Du) = 0;
    find(sub { $Du += -s; }, $dir);
    $self->{SIZE}{$dir} = $Du/1024/1024;
    push @{$self->{FIFO}}, $dir;
    $self->debug("measured $dir is $Du") if $CPAN::DEBUG;
    $self->{DU} += $Du/1024/1024;
    if ($self->{DU} > $self->{'MAX'} ) {
	printf "...Hold on a sec... CPAN's cleaning the cache: %.2f MB > %.2f MB\n",
		$self->{DU}, $self->{'MAX'};
	$self->clean_cache;
    } else {
	$self->debug("NOT have to clean the cache: $self->{DU} <= $self->{'MAX'}") if $CPAN::DEBUG;
	$self->debug($self->as_string) if $CPAN::DEBUG;
    }
    $self->{DU};
}

sub force_clean_cache {
    my($self,$dir) = @_;
    $self->debug("have to rmtree $dir, will free $self->{SIZE}{$dir}") if $CPAN::DEBUG;
    File::Path::rmtree($dir);
    $self->{DU} -= $self->{SIZE}{$dir};
    delete $self->{SIZE}{$dir};
}

sub new {
    my $class = shift;
    my $self = { ID => $CPAN::Config->{'build_dir'}, MAX => $CPAN::Config->{'build_cache'}, DU => 0 };
    File::Path::mkpath($self->{ID});
    my $dh = DirHandle->new($self->{ID});
    bless $self, $class;
    $self->debug("dir [$self->{ID}]") if $CPAN::DEBUG;
    my $e;
    for $e ($self->entries) {
	next if $e eq ".." || $e eq ".";
	$self->debug("Have to check size $e") if $CPAN::DEBUG;
	$self->disk_usage($e);
    }
    $self;
}

package CPAN::Debug;

# VERRY PRIMITIVE, sorry XXX

sub debug {
    my($self,$arg) = @_;
    my($caller,$func,$line) = caller();
    $caller =~ s/.*:://;
    print "Debug($caller\[$CPAN::DEBUG{$caller}]:$func:$line): $arg\n" if $CPAN::DEBUG{$caller} & $CPAN::DEBUG;
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

CPAN - query, download and build perl modules from CPAN sites

=head1 SYNOPSIS

Interactive mode:

  perl -MCPAN -e shell;

Batch mode:

  use CPAN;

  autobundle, bundle, bundles, expand, install, make, test

=head1 DESCRIPTION

The CPAN module is designed to automate the fetching and, optionally,
the building and installing of perl modules and extensions.

Modules are fetched from one or more of the mirrored CPAN
(Comprehensive Perl Archive Network) sites and unpacked in a dedicated
directory.

The CPAN module also supports the concept of named and versioned
'bundles' of modules. Bundles simplify the handling of sets of
related modules. See BUNDLES below.

The package contains a session manager and a cache manager. There is
no status retained between sessions. The session manager keeps track
of what has been fetched, built and installed in the current session
and will nor redo a 'make' or a 'install'. 'test' can be run
repeatedly.

=head2 Interactive Mode

The interactive mode is entered by running

    perl -MCPAN -e shell

which puts you into a readline interface. You will have most fun if
you install Term::ReadKey and Term::ReadLine soon. That will give you
both history and completion.

Once you're on the command line, type 'h' and the rest should be
self-explanatory.

=head2 Cache Manager

Currently the cache manager only keeps track of the build directory
($CPAN::Config->{build_dir}). It is a simple FIFO mechanism that
deletes complete directories below build_dir as soon as the size of
all directories there gets bigger than $CPAN::Config->{build_cache}
(in MB).

There is another directory ($CPAN::Config->{keep_source_where}) where
the original distribution files are kept. This directory is not
covered by the cache manager and must be controlled by the user. If
you choose to have the same directory as build_dir and as
keep_source_where directory, then your sources will be deleted with
the same fifo mechanism.

=head2 Prerequisites

If you have a local mirror of CPAN and can access all files with
"file:" URLs, then you only need perl5.003 to run this
module. Otherwise you need Net::FTP intalled. LWP may be required for
non-UNIX systems.

This module presumes that all packages on CPAN

=over 2

=item *

Declare their $VERSION variable in an easy to parse manner. This
prerequisite can hardly be relaxed because it consumes by far too much
memory to load all packages into a single program just to determine
the $VERSION variable . Currently all programs that are dealing with
VERSION use something like this (requires MakeMaker-5.38, but don't
bother if you don't have it):

    perl -MExtUtils::MakeMaker -le \
        'print MM->parse_version($ARGV[0])' filename

If you are author of a package and wonder if your VERSION can be
parsed, please try the above method.

=item *

come as compressed or gzipped tarfiles or as zip files,

=back

=head2 Bundles

A bundle is just a perl module in the namespace Bundle:: that does not
define any functions or methods. It usually only contains documentation.

It starts like a perl module with a package declaration and a $VERSION
variable. After that the pod section looks like any other pod with the
only difference, that one pod section exists starting with (verbatim):

	=head1 CONTENTS

In this pod section each line obeys the format

        Module_Name [Version_String] [- optional text]

The only required part is the first field, the name of a module
(eg. Foo::Bar, ie. I<not> the name of the distribution file). The rest
of the line is optional. The comment part is delimited by a dash just
as in the man page header.

The distribution of a bundle should follow the same convention as
other distributions. The bundle() function in the CPAN module simply
parses the module that defines the bundle and returns the module names
that are listed in the described CONTENTS section.

Bundles are treated specially in the CPAN package. If you say 'install
Bundle::Tkkit' (assuming such a bundle exists), CPAN will install all
the modules in the CONTENTS section of the pod.  You can install your
own Bundles locally by placing a conformant Bundle file somewhere into
your @INC path. The autobundle() command does that for you by
including all currently installed in a snapshot bundle file.

=head2 autobundle

autobundle() writes a bundle file into the directory
$CPAN::Config->{cpan_home}/Bundle directory. The file contains a list
of all modules that are both available from CPAN and currently
installed within @INC. The name of the bundle file is based on the
current date and a counter.

=head1 CONFIGURATION

When the CPAN module is installed a site wide configuration file is
created as CPAN/Config.pm. The default values defined there can be
overridden in another configuration file: CPAN/MyConfig.pm. You can
store this file in $HOME/.cpan/CPAN/MyConfig.pm if you want, because
$HOME/.cpan is added to the search path of the CPAN module before the
use() or require() statements.

Currently the following keys in the hash reference $CPAN::Config are
defined:

  build_cache       size of cache for directories to build modules
  build_dir         locally accessible directory to build modules
  cache_expire      after how many days refetch index files
  cpan_home         local directory reserved for this package
  gzip		    location of external program gzip
  inhibit-startup-message
                    if true, does not print the startup message
  keep_source       keep the source in a local directory?
  keep_source_where where keep the source (if we do)
  make              location of external program make
  make_arg	    arguments that should always be passed to 'make'
  make_install_arg  same as make_arg for 'make install'
  makepl_arg	    arguments passed to 'perl Makefile.PL'
  more              location of external program more (or any pager)
  tar               location of external program tar
  unzip             location of external program unzip
  urllist	    arrayref to nearby CPAN sites (or equivalent locations)

=head1 SECURITY

There's no security layer in the alpha version of CPAN.pm. CPAN.pm
helps you to install foreign, unmasked, unsigned code on your
machine. It's not different than when you do that on your own, but you
should be warned now.

=head1 EXPORT

All functions in package CPAN are exported. The reason for this is
that the primary use is intended for the cpan-shell or for one-liners.

=head1 Debugging

The debugging of this module is a pretty difficult task, because we
have interferences of the software producing the indices on CPAN, of
the mirroring process, of improper packaging, of improper
configuration and of bugs within CPAN.pm. 

In interactive mode you can try "o debug" which will list options for
debugging the various parts of the package. The output may not be very
useful for you as it's just a byproduct of my own testing, but if you
have an idea which part of the package may have a bug, it's certainly
worth to give it a try and send me more specific output.

=head1 AUTHOR

Andreas König E<lt>a.koenig@mind.deE<gt>

=head1 SEE ALSO

perl(1)

=cut

