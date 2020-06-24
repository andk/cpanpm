package Bundle::CPANxxl;
use strict;
use vars qw($VERSION);
$VERSION = '0.4';

1;

__END__

=head1 NAME

Bundle::CPANxxl - Bundle with a few more components than Bundle::CPAN

=head1 SYNOPSIS

 cpan Bundle::CPANxxl

=head1 CONTENTS

YAML::Syck

IO::Tty -- if we are not explicit, we get a delay and YAML comes interactively

Expect

YAML

Bundle::CPAN

Module::Info

CPAN::Reporter

Kwalify

V

Devel::PatchPerl

Module::Versions::Report

=head1 DESCRIPTION

This bundle includes Bundle::CPAN plus what I consider indispensible
but not everybody can compile, namely Expect and YAML.

I've taken the liberty to also add YAML::Syck because of its speed
advantage.

Kwalify verifies that the files in the prefs_dir/ directory are
written according to the specs.

Last not least every full installation of CPAN needs the
CPAN::Reporter. I put it into this xxl bundle because it may be a bit
overkill for small installations. Maybe we will shift it over to
Bundle::CPAN.

After several years of frugality I found also indispensible:
Module::Info, V, Devel::PatchPerl, and Module::Versions::Report.

=head1 AUTHOR

Andreas Koenig
