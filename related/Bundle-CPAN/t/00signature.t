# -*- mode: cperl -*-

use strict;
print "1..1\n";

if (0) {
} elsif (!-f 'SIGNATURE') {
  print "ok 1 # skip No signature file\n";
} elsif (!-s 'SIGNATURE') {
  print "ok 1 # skip Empty signature file\n";
} elsif (!eval { require Module::Signature; 1 }) {
  print "ok 1 # skip - no Module::Signature found [INC = @INC]\n";
} elsif (!eval { require Socket; Socket::inet_aton('pgp.mit.edu') }) {
  print "ok 1 # skip - Cannot connect to the keyserver";
} else {
  (Module::Signature::verify() == Module::Signature::SIGNATURE_OK())
      or print "not ";
  print "ok 1 # Valid signature\n";
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
