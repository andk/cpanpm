#!/usr/bin/perl -w
use lib "lib";
use ExtUtils::MakeMaker qw(:DEFAULT neatvalue);
use File::Path;


# use strict;

# $Id: Makefile.PL,v 1.11 1996/09/09 23:12:19 k Exp k $

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'CONFIGURE' => \&init,
    'NAME'	=> 'CPAN',
    'VERSION_FROM' => 'lib/CPAN.pm',
    'dist' => { DIST_DEFAULT => 'private all tardist', COMPRESS => 'gzip -9f' },
);

sub init {
    use Config;
    require CPAN;
    eval {require CPAN::Config;};
    $CPAN::Config ||= {};
    
    my($ans,@valid,$default,$configpm,$local,%ALL,$cont,@pos,$url);
    
    print qq{

The CPAN module needs a directory of its own to cache important
index files and maybe keep a temporary mirror of CPAN files. This may
be a site-wide directory or a personal directory.
};

    my $cpan_home = $CPAN::Config->{cpan_home} || MM->catdir($ENV{HOME}, ".cpan");
    if (-d $cpan_home) {
	print qq{

I see you already have a  directory
    $cpan_home
Shall we use it as the general CPAN build and cache directory?

};
    } else {
	print <<END;

First of all, I\'d like to create this directory. Where?

END
}
    $default = $cpan_home;
    $ans = prompt("CPAN build and cache directory?",$default) || $default;
    mkpath($ans); # dies if it can't
    $CPAN::Config->{cpan_home} = $ans;
    
    print qq{

If you want, I can keep the source files after a build in the cpan
home directory. If you choose so then future builds will take the
files from there. If you don\'t want to keep them, answer 0 to the
next question.

};

#    $default = $CPAN::Config->{keep_source_mb}>0 ? $CPAN::Config->{keep_source_mb} : 10;
#    $ans = prompt("How much diskspace do you want to dedicate to keeping sources (in MB)?", $default) || $default;
#    $CPAN::Config->{keep_source_mb} = $ans;

    $CPAN::Config->{keep_source_where} = MM->catdir($CPAN::Config->{cpan_home},"sources");
    $CPAN::Config->{build_dir} = MM->catdir($CPAN::Config->{cpan_home},"build");

    print <<END;

How big should the disk cache be for keeping the build directories
with all the intermediate files?

END

    $default = $CPAN::Config->{build_cache} || 10;
    $ans = prompt("Cache size for build directory (in MB)?", $default) || $default;
    $CPAN::Config->{build_cache} = $ans;

    # XXX This the time when we refetch the index files (in days)
    $CPAN::Config->{cache_expire} = 1;

    print <<END;

The CPAN module will need a few external programs to work
properly. Please correct me, if I guess the wrong path for a program.

END

    my(@path) = split($Config{path_sep},$ENV{PATH});
    my $prog;
    for $prog (qw/gzip tar unzip make/){
	my $path = $CPAN::Config->{$prog} || find_exe($prog,[@path]) || $prog;
	$ans = prompt("Where is your $prog program?",$path) || $path;
	$CPAN::Config->{$prog} = $ans;
    }
    for $prog (qw/more/){
	my $path = $CPAN::Config->{$prog} || 
	    $ENV{PAGER} || find_exe("less",[@path]) || 
		find_exe($prog,[@path]) || $prog;
	$ans = prompt("Where is your $prog program?",$path) || $path;
	$CPAN::Config->{$prog} = $ans;
    }

print <<END;

Every Makefile.PL is run by perl in a seperate process. Likewise we
run 'make' and 'make install' in processes. If you have any parameters
(e.g. PREFIX, INSTALLPRIVLIB, UNINST or the like) you want to pass to
the calls, please specify them here.

END

    $default = $CPAN::Config->{makepl_arg} || "";
    $CPAN::Config->{makepl_arg} =
	prompt("Parameters for the 'perl Makefile.PL' command?",$default) || $default;
    $default = $CPAN::Config->{make_arg} || "";
    $CPAN::Config->{make_arg} = prompt("Parameters for the 'make' command?",$default) || $default;

    $default = $CPAN::Config->{make_install_arg} || $CPAN::Config->{make_arg} || "";
    $CPAN::Config->{make_install_arg} =
	prompt("Parameters for the 'make install' command?",$default) || $default;

    {
	my $local = 'MIRRORED.BY';
	my($host,$dst,$country,$continent,@location);
	open FH, $local or die "Couldn't open $local: $!";
	while (<FH>) {
	    ($host) = /^([\w\.\-]+)/ unless defined $host;
	    next unless defined $host;
	    next unless /\s+dst_(dst|location)/;
	    /location\s+=\s+\"([^\"]+)/ and @location = (split /\s*,\s*/, $1) and
		($continent, $country) = @location[-1,-2];
	    $continent =~ s/\s\(.*//;
	    /dst_dst\s+=\s+\"([^\"]+)/  and $dst = $1;
	    next unless $host && $dst && $continent && $country;
	    $ALL{$continent}{$country}{$dst}++;
	    undef $host;
	    $dst=$continent=$country="";
	}
    }

    $local = 0;
    for $cont (sort {$a cmp $b} keys %ALL) {
	my $country;
	push @valid, "    $cont\n";
	for $country (sort {lc $a cmp lc $b} keys %{$ALL{$cont}}) {
	    # push @valid, "        $country\n";
	    for $url (sort {lc $a cmp lc $b} keys %{$ALL{$cont}{$country}}) {
		$local++;
		push @valid, sprintf "      %-18s (%2d) %s\n", $country, $local, $url;
		$pos[$local] = $#valid;
	    }
	}
    }
#    my $start_from_old = $local+1;
    my $official_list_end = $local;
    if (@{$CPAN::Config->{urllist} || []}) {
	push @valid, "    from your old Config file:\n";
	for $url (@{$CPAN::Config->{urllist}}) {
	    $local++;
	    push @valid, sprintf "      %-18s (%2d) %s\n", "found URL", $local, $url;
	    $pos[$local] = $#valid;
	}
	@{$CPAN::Config->{urllist}} = ();
    }

    print <<END;

Now we need to know, where your favorite CPAN sites are located. Push
a few sites onto the array (just in case the first on the array won't
work). If you are mirroring CPAN to your local workstation, specify a
file: URL.

You can enter the number in front of the URL on the next screen, a
file:, ftp: or http: URL, or "q" to finish selecting.

END

# ';}

    $ans = prompt("Press RETURN to continue");
    my $other;
    $ans = $other = "";
    while (1) {
	open FH, "| $CPAN::Config->{more} ";
	print FH @valid;
	close FH;
	$default = first_after($official_list_end,@valid);
	$default ||= my_dom(@valid);
	#print join ":", $#pos, $#valid, $pos[-1], "\n";
	$ans = prompt("\nSelect an$other ftp or file URL or a number (q to finish)",$default) || $default;
	my $sel;
	if ($ans =~ /^\d/) {
	    #print "Got $ans (corr $pos[$ans] corr $valid[$pos[$ans]])\n";
	    $sel = $valid[$pos[$ans]];
	    $sel =~ s/^.+?\(\s*\d+\)\s+//;
	    $sel =~ s/\s+$//;
	    $sel =~ s|/?$|/|; # has to end with one slash
	    push @{$CPAN::Config->{urllist}}, $sel;
	    splice(@valid,$pos[$ans],1);
	    for ($ans..$#pos) {
		$pos[$_]--;
	    }
	} elsif (@{$CPAN::Config->{urllist}} && $ans =~ /^q|$/i) {
	    last;
	} else {
	    $ans =~ s|/?$|/|; # has to end with one slash
	    $ans = "file:$ans" unless $ans =~ /:/; # without a scheme is a file:
	    push @{$CPAN::Config->{urllist}}, $ans;
	}
	$other ||= "other";
    }

    print "\n\n";
    $configpmdir = MM->catdir(qw/lib CPAN/);
    mkpath $configpmdir;
    $configpm = MM->catfile( qw/lib CPAN Config.pm/ ); 

    open FH, ">$configpm" or die "Couldn't open >$configpm: $!";
    print FH qq[\$CPAN::Config = \{\n];
    foreach (sort keys %$CPAN::Config) {
	print FH "  '$_' => ", neatvalue($CPAN::Config->{$_}), ",\n";
    }

    print FH "};\n1;\n__END__\n";

    my $configpm2 = MM->catfile($ENV{HOME},qw(.cpan CPAN Config.pm));
    if (-f $configpm2) {
	print qq{

I\'ve found a CPAN::Config file as $configpm2. If this is an old
configuration file, please remove it or make sure that it doesn\'t
conflict with the one we just created in $configpm. If you want, I can
remove the old one right now.

};
	$ans = prompt("Shall I remove the old $configpm2 now?", "NO") || "NO";
	unlink $configpm2 if $ans =~ /^y/i;
    }
}

sub MY::postamble {
    my($self) = shift;
    my @m;
    my $cpandir = $CPAN::Config->{cpan_home};
    my $configpm_from = $self->catfile("lib","CPAN","Config.pm");
    my $configpm_to = $self->catfile($cpandir,"Config.pm");
    push @m, qq{
# This is only for me (Andreas Koenig) for the distribution
private: MIRRORED.BY

MIRRORED.BY: /usr/sources/CPAN/MIRRORED.BY.gz
	/usr/local/bin/zcat \$? > \$\@
};
    return join "", @m;
}

sub find_exe {
    my($exe,$path) = @_;
    my($dir,$MY);
    $MY = {};
    bless $MY, 'MY';
    for $dir (@$path) {
	my $abs = $MY->catfile($dir,$exe);
	if ($MY->maybe_command($abs)) {
	    return $abs;
	}
    }
}

sub first_after ($@) {
    my($official_list_end,@valid) = @_;
    foreach (@valid) {
	/.*\((.+?)\)/ || next;
	my $n = $1;
	return $n if $n > $official_list_end;
    }
}

sub my_dom (@) {
    my(@valid) = @_;
    my $domain = "";
    eval {
	require Net::Domain;
	$domain = Net::Domain::domainname();
	$domain =~ s/.*\.//;
    };
    return unless $domain;
    foreach (@valid) {
	/.*\((.+?)\)\s+ftp:\/\/[^\/]+\.(\w+)\// || next;
	my $n = $1;
	my $d = $2;
	return $n if $d eq $domain;
    }
}
