use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'	       => 'Local::Test::Fails',
	'ABSTRACT'     => 'This distribution has a hopeless test failure',
	'VERSION'      => '1.0',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

	'PREREQ_PM'    => {
		'Test::More' => '0',
		},

	'PM'           => {
		'lib/Fails.pm'         => '$(INST_LIBDIR)/Fails.pm',
		},

	clean  => { FILES    => q|Local-Test-Fails-*| },

	);
