package Bundle::CPAN;
use strict;
use vars qw($VERSION);
$VERSION = '1.861'; # use 3 digits to minimize confusion with the
                    # other CPAN.pm

1;

__END__

=head1 NAME

Bundle::CPAN - Bundle to optimize the behaviour of CPAN.pm

=head1 SYNOPSIS

 perl -MCPAN -e 'install Bundle::CPAN'

=head1 CONTENTS

ExtUtils::MakeMaker -- bundles sane ExtUtils::Install

Test::Harness -- critical prereq because must be >=2.62

ExtUtils::CBuilder -- some of the things below depend on it without declaring (as of 2006-10)

File::Temp -- prereq

Test::More -- prereq

Data::Dumper

IO::Compress::Base -- 2009-07-02, new master IO::Compress::* package,

Compress::Zlib -- needed by Archive::Tar

IO::Zlib -- needed by Archive::{Tar,Zip}

Archive::Tar -- needed by Module::Build

Module::Build -- needed by File::Spec

File::Spec -- prereq

Digest::SHA

File::HomeDir

Archive::Zip

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
modules. The other modules are B<suggested> and can safely be
installed later.

Please install the Bundle::CPANxxl to get a few more.

=head1 AUTHOR

Andreas Koenig
