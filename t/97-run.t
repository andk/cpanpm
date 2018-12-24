use Test::More;
use File::Spec;

my $file = File::Spec->catfile('blib', 'script', 'cpan');

print "bail out! Script file is missing!" unless -e $file;

my $output = `$^X -Ilib $file -y 2>&1`;
like( $output, qr/Unknown option: y/, 'refuse unknown parameter' );

$output = `$^X -Ilib $file -h 2>&1`;
for my $switch (qw(a A c C D f F g G h i I j J l m M n O P r s t T u v V w x X)) {
    like( $output, qr/^[ ]+-\Q$switch\E/m, "advertizing $switch" );
}

done_testing();
