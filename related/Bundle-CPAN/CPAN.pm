package Bundle::CPAN;
use strict;
use vars qw($VERSION);
$VERSION = '1.858'; # use 3 digits to minimize confusion with the
                    # other CPAN.pm

1;

__END__

=head1 NAME

Bundle::CPAN - Bundle to optimize the behaviour of CPAN.pm

=head1 SYNOPSIS

 perl -MCPAN -e 'install Bundle::CPAN'

=head1 CONTENTS

Test::Harness -- critical prereq because must be >=2.62

ExtUtils::CBuilder -- some of the things below depend on it without declaring (as of 2006-10)

ExtUtils::MakeMaker

Module::Build

File::Spec -- prereq

File::Temp -- prepreq

Scalar::Util -- prereq

Test::More -- prereq

Data::Dumper

Digest::SHA

File::HomeDir

Compress::Raw::Bzip2 -- needed by Compress::Zlib or IO::Compress, not sure

Compress::Raw::Zlib -- needed by Compress::Zlib

IO::Compress::Base -- needed by Compress::Zlib

IO::Uncompress::Gunzip -- really IO::Compress::Zlib -- needed by Compress::Zlib

Compress::Zlib

IO::Zlib -- needed by Archive::{Tar,Zip}

Archive::Tar

Archive::Zip

Net::Cmd -- not sure if we need this for Net::FTP

Net::FTP

Term::ReadKey

Term::ReadLine::Perl -- could be replaced by "readline" some time after 1.88

YAML -- user may have a preference for YAML::Syck but as a bundle we don't know

Parse::CPAN::Meta -- 2009-07-02: 5.6.2 currently has no YAML

Text::Glob

CPAN

File::Which

=head1 DESCRIPTION

This bundle includes CPAN.pm as the base module.

When CPAN installs this bundle it tries immediately to enable
Term::ReadLine so that you do not need to restart your CPAN session.

In this bundle Term::ReadLine::Perl is preferred over
Term::ReadLine::Gnu because there is no way to express I<OR> in
dependencies.

Note that all modules in this Bundle are not strict prerequisites to
get a working CPAN.pm. CPAN.pm can work quite well without the other
modules (except for Net::FTP which is really highly recommended). The
other modules are B<suggested> and can safely be installed later or
not at all.

Please install the Bundle::CPANxxl to get a few more.

=head1 AUTHOR

Andreas Koenig
