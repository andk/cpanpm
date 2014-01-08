use Cwd qw(cwd);

use CPAN::Checksums qw(updatedir);
my $success = updatedir( cwd() );
