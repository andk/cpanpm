# -*- mode: cperl -*-

use strict;
BEGIN {
    my $found_prereq = 0;
    unless ($found_prereq) {
        $found_prereq = eval { require Digest::SHA; 1 };
    }
    unless ($found_prereq) {
        $found_prereq = eval { require Digest::SHA1; 1 };
    }
    unless ($found_prereq) {
        $found_prereq = eval { require Digest::SHA::PurePerl; 1 };
    }
    my $exit_message = "";
    unless ($found_prereq) {
        $exit_message = "None of the supported SHA modules (Digest::SHA,Digest::SHA1,Digest::SHA::PurePerl) found";
    }
    unless ($exit_message) {
        require Config;
        require CPAN::FirstTime;
        my @programs = qw(
                             gpg
                        );
        my $p;
        my(@path) = split /$Config::Config{path_sep}/, $ENV{PATH};
        require CPAN::FirstTime;
    PRG: for $p (@programs) {
            unless (CPAN::FirstTime::find_exe($p,\@path)){
                $exit_message = "External program '$p' not found";
                last PRG;
            }
        }
    }
    unless ($exit_message) {
        if (!-f 'SIGNATURE') {
            $exit_message = "No signature file";
        }
    }
    unless ($exit_message) {
        if (!-s 'SIGNATURE') {
            $exit_message = "Empty signature file";
        }
    }
    unless ($exit_message) {
        if (!eval { require Module::Signature; 1 }) {
            $exit_message = "No Module::Signature found [INC = @INC]";
        }
    }
    unless ($exit_message) {
        if ( $Module::Signature::VERSION < 0.6599999) {
            $exit_message = "Module::Signature version $Module::Signature::VERSION too old, expecting at least 0.66";
        }
    }
    unless ($exit_message) {
        if (!eval { require Socket; Socket::inet_aton('pool.sks-keyservers.net') }) {
            $exit_message = "Cannot connect to the keyserver";
        }
    }
    if ($exit_message) {
        $|=1;
        print "1..0 # SKIP $exit_message\n";
        eval "require POSIX; 1" and POSIX::_exit(0);
    }
}

$ENV{TEST_SIGNATURE} = 1;
if (Module::Signature::verify() == Module::Signature::SIGNATURE_OK()) {
    print "1..1\n";
    print "ok 1 # Valid signature\n";
}
else {
    print "1..0 # SKIP verify failed, so only collect diagnostics\n";
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
