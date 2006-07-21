package Bundle::CPAN;
use strict;
use vars qw($VERSION);
$VERSION = '1.852'; # use 3 digits to minimize confusion with the
                    # other CPAN.pm

1;

__END__

=head1 NAME

Bundle::CPAN - Bundle to optmize the behaviour of CPAN.pm

=head1 SYNOPSIS

 perl -MCPAN -e 'install Bundle::CPAN'

=head1 CONTENTS

Digest::SHA

File::Temp

File::HomeDir

File::Spec

Compress::Zlib

Archive::Tar

Archive::Zip

Bundle::libnet

Term::ReadKey

ILYAZ/modules/Term-ReadLine-Perl-1.0302.tar.gz

YAML

Text::Glob

Module::Build

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

=head1 AUTHOR

Andreas Koenig
