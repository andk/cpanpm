while (<>) {
  die if /\cM/;
  next unless /^(\S+)/;
  my $file = $1;
  open FH, $file or die;
  next if -B $file;
  while (<FH>) {
    die "Found CR in $file" if /\cM/;
  }
}
