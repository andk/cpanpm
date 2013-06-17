while (<>) {
  die "contains CR" if /\cM/;
  next unless /^(\S+)/;
  my $file = $1;
  next if "SIGNATURE" eq $file and ! -f $file;
  unless (open FH, $file) {
      warn "Warning (maybe harmless): Could not open '$file': $!";
      next;
  }
  next if -B $file;
  while (<FH>) {
    die "Found CR in $file" if /\cM/;
  }
}
