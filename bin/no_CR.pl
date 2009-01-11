while (<>) {
  die "contains CR" if /\cM/;
  next unless /^(\S+)/;
  my $file = $1;
  next if "SIGNATURE" eq $file and ! -f $file;
  open FH, $file or die "Could not open '$file': $!";
  next if -B $file;
  while (<FH>) {
    die "Found CR in $file" if /\cM/;
  }
}
