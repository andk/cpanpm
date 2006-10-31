package Bundle::CPANxxl;
use strict;
use vars qw($VERSION);
$VERSION = '0.1';

1;

__END__

=head1 NAME

Bundle::CPANxxl - Bundle with a few more components than Bundle::CPAN

=head1 SYNOPSIS

 cpan Bundle::CPANxxl

=head1 CONTENTS

YAML::Syck

Expect

YAML

Bundle::CPAN

Module::Signature

CPAN::Reporter

=head1 DESCRIPTION

This bundle includes Bundle::CPAN plus what I consider indispensible
but not everybody can compile, namely Expect and Module::Signature.

I've taken the liberty to also add YAML::Syck because of its speed
advantage.

Last not least every full installation of CPAN needs the
CPAN::Reporter. I put it into this xxl bundle because it may be a bit
overkill for small installations. Maybe we will shift it over to
Bundle::CPAN.

=head1 AUTHOR

Andreas Koenig
