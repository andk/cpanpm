use strict;
use DBM::Deep;
use Storable qw(retrieve);

my $metadata = retrieve "/home/akoenig/.cpan/Metadata";
my $dbmdeep = DBM::Deep->new("/tmp/deep2.dbm") or die $!;
$dbmdeep->import($metadata);

