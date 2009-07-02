# -*- mode: cperl -*-

use strict;
print "1..1\n";

my $skip;
if (0) {
} elsif (!-f 'SIGNATURE') {
  $skip = "No signature file";
} elsif (!-s 'SIGNATURE') {
  $skip = "Empty signature file";
} elsif (!eval { require Module::Signature; 1 }) {
  $skip = "no Module::Signature found [INC = @INC]";
} elsif (!eval { require Socket; Socket::inet_aton('pgp.mit.edu') }) {
  $skip = "Cannot connect to the keyserver";
}
if ($skip) {
  warn "skipping: $skip\n";
  print "ok 1 # skip - $skip\n";
} else {
  (Module::Signature::verify() == Module::Signature::SIGNATURE_OK())
      or print "not ";
  print "ok 1 # Valid signature\n";
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
