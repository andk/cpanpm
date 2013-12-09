use strict;
use ExtUtils::MakeMaker qw(WriteMakefile);

WriteMakefile
    (
     CONFIGURE_REQUIRES =>
     {
      "ExtUtils::MakeMaker" => "6.46", # for META_ADD
     },
     NAME          => 'CPAN::Test::Dummy::Perl5::Make::CircularPrereq',
     VERSION       => '1.00',
     ABSTRACT      => 'CPAN Test Dummy for CPAN.pm',
     ($ExtUtils::MakeMaker::VERSION >= 6.31 ?
      (LICENSE      => "perl") : (),
     ),
     PREREQ_PM =>
     {
      "CPAN::Test::Dummy::Perl5::Make::OptionalPrereq" => "0.42",
     },
);
