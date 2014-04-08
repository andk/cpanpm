use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'	       => 'Local::Works::Fine',
	'ABSTRACT'     => 'This is what the module does',
	'VERSION_FROM' => 'lib/Fine.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

	'PREREQ_PM'    => {
		'Test::More' => '0',
		},

	'PM'           => {
		'lib/Fine.pm'         => '$(INST_LIBDIR)/Fine.pm',
		},

	'MAN3PODS'     => {
		'lib/Fine.pm' => '$(INST_MAN3DIR)/Local::Works::Fine.3',
		},

	clean  => { FILES    => q|Local-Works-Fine-*| },

	);
