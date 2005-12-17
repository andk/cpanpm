package CPAN::Debug;
use strict;
use vars qw($VERSION);

$VERSION = sprintf "%.2f", substr(q$Rev$,4)/100;
# module is internal to CPAN.pm

#-> sub CPAN::Debug::debug ;
sub debug {
    my($self,$arg) = @_;
    my($caller,$func,$line,@rest) = caller(1); # caller(0) eg
                                               # Complete, caller(1)
                                               # eg readline
    ($caller) = caller(0);
    $caller =~ s/.*:://;
    $arg = "" unless defined $arg;
    my $rest = join "|", map { defined $_ ? $_ : "UNDEF" } @rest;
    if ($CPAN::DEBUG{$caller} & $CPAN::DEBUG){
	if ($arg and ref $arg) {
	    eval { require Data::Dumper };
	    if ($@) {
		$CPAN::Frontend->myprint($arg->as_string);
	    } else {
		$CPAN::Frontend->myprint(Data::Dumper::Dumper($arg));
	    }
	} else {
	    $CPAN::Frontend->myprint("Debug($caller:$func,$line,[$rest]): $arg\n");
	}
    }
}

1;
