#!/usr/bin/perl

# use 5.010;
use strict;
use warnings;

=head1 NAME

dagolden-reversion-gist

=head1 SYNOPSIS

perl $0 commitish

=head1 OPTIONS

=over 8

=cut

my @opt = <<'=back' =~ /B<--(\S+)>/g;

=item B<--help|h!>

This help

=back

=head1 DESCRIPTION

Found at https://gist.github.com/dagolden/858394

=head1 AUTHOR

From shebang to Local Variables it is dagolden, the rest is mine.

=cut


use FindBin;
use lib "$FindBin::Bin/../lib";
BEGIN {
    push @INC, qw(       );
}

use Dumpvalue;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Spec;
use File::Temp;
use Getopt::Long;
use Pod::Usage;
use Hash::Util qw(lock_keys);

our %Opt;
lock_keys %Opt, map { /([^=|!]+)/ } @opt;
GetOptions(\%Opt,
           @opt,
          ) or pod2usage(1);
if ($Opt{help}) {
    pod2usage(0);
}

#!/usr/bin/env perl
use 5.010;
use strict;
use warnings;
use autodie;
use Git::Wrapper;
use File::Find::Rule ();
use File::Find::Rule::Perl ();
 
my $tag = shift
or die "Usage: $0 <tag>\n";
 
my $git = Git::Wrapper->new(".");
 
my @files = File::Find::Rule->perl_file->in("lib");
 
for my $file ( @files ) {
my @diff = $git->diff( "$tag", "--", $file );
next unless @diff;
say "$file: " . scalar @diff . " diff lines";
my @version_lines = map { " $_" } grep { /\$(?:(?:\w+::)+)*VERSION\s*=\s*/ } @diff;
if ( @version_lines ) {
say for @version_lines;
}
else {
say " *** NEEDS VERSION BUMP! ***";
}
}



# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
