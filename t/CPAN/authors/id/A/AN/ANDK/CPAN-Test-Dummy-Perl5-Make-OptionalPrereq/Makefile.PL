use strict;
use ExtUtils::MakeMaker qw(WriteMakefile);

WriteMakefile
    (
     CONFIGURE_REQUIRES =>
     {
      "ExtUtils::MakeMaker" => "6.46", # for META_ADD
     },
     NAME          => 'CPAN::Test::Dummy::Perl5::Make::OptionalPrereq',
     VERSION       => '1.00',
     ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
     ($ExtUtils::MakeMaker::VERSION >= 6.31 ?
      (LICENSE      => "perl") : (),
     ),
     META_ADD =>
     {
      recommends =>
      {
       "CPAN::Test::Dummy::Perl5::Make::CircularPrereq" => "0.14",
       "CPAN::Test::Dummy::Perl5::Make::NotExistingPrereq" => "0.123",
      },
     },
);
