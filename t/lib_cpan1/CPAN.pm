BEGIN {  *CORE::GLOBAL::exit = sub { 23 } };


package CPAN;

no warnings 'redefine';

sub shell {
	print "I am the shell!\n";
	}

sub CPAN::HandleConfig::load {
	print "Loading config\n";
	}

sub CPAN::Shell::install {
	return 'install';
	}

sub CPAN::Shell::force {
	return 'force';
	}

1;
