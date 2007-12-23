my $count;
use strict;
use Cwd;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
sub _f ($) {
    File::Spec->rel2abs(File::Spec->catfile(split /\//, shift));
}
unshift @INC, "t";
require CPAN::MyConfig;
require CPAN;
require CPAN::Kwalify;
require CPAN::HandleConfig;
require CPAN::Tarzip;
{
    my $tgz = _f("t/CPAN/authors/id/A/AN/ANDK/CPAN-Test-Dummy-Perl5-Build-1.03.tar.gz");
    my $CT = CPAN::Tarzip->new($tgz);
    my $tmpdir = tempdir("t/13tarzipXXXX", CLEANUP => 1);
    my $cwd = Cwd::cwd;
    chdir $tmpdir or die "Could not chdir to '$tmpdir': $!";
    ok($CT->untar, "untar/ungzip should not throw an error");
    chdir $cwd;
    BEGIN{$count++;}
}
BEGIN{plan tests => $count}

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
