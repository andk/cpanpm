package Bundle::CPAN;

$VERSION = '1.58';

1;

__END__

=head1 NAME

Bundle::CPAN - A bundle to play with all the other modules on CPAN

=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::CPAN'>

=head1 CONTENTS

File::Spec

MD5

Compress::Zlib

Archive::Tar

Bundle::libnet

Term::ReadKey

Term::ReadLine::Perl # sorry, I'm discriminating the ::Gnu module

CPAN::WAIT

CPAN

=head1 DESCRIPTION

This bundle includes CPAN.pm as the base module and CPAN::WAIT, a
plugin for the first WAIT based CPAN search engine.

When CPAN installs this bundle it tries immediately to enable
Term::ReadLine so that you do not need to restart your CPAN session.

Compress::Zlib needs as a prerequisite the zlib library. Currently
(January 1998) this library is not shipped with the Compress::Zlib
distribution.

In this bundle Term::ReadLine::Perl is preferred over
Term::ReadLine::Gnu because I expect that it gives less problems on
portability.

Note that all modules in this Bundle are not strict prerequisites to
get a working CPAN.pm. CPAN.pm can work quite well without the other
modules (except for Net::FTP which is really highly recommended). The
other modules are just goodies that make using CPAN.pm more fun.

=head1 AUTHOR

Andreas König
