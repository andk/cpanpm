The heart of the testing mechanism is shell.t which is based on Expect
and as such is able to test a shell session. To make reproducable
tests we need a shell session that is based on a clone of a
miniaturized CPAN site. This site lives under t/CPAN/{authors,modules}.

Our first distribution in the mini CPAN site was

    A/AN/ANDK/CPAN-Test-Dummy-Perl5-Make-1.01.tar.gz

which was a clone of PITA::Test::Dummy::Perl5::Make.

Now we need more distros, based on the following criteria:

Testing:        success/failure
Installer:      EU:MM/M:B/M:I
YAML:           with/without
SIGNATURE:      with/without
Zipping:        tar.gz/tar.bz2/zip

Any new distro must be separately available on CPAN so that our
CHECKSUMS files can be signed real ones and we need not introduce a
backdoor into the shell to ignore signatures.

To add a new distro, the following steps must be taken:

(1) Collect the source

- svn mkdir the author's directory if it doesn't exist yet

- svn add (or svn cp) the whole source code under the author's homedir

- add the source code directory with a trailing slash to MANIFEST.SKIP

- finish now the distro until it does what you intended

(2) Create the distro zipfile

- add a stanza to CPAN.pm's Makefile.PL that produces the distro with
  the whole dependency on all files within the distro and moves it up
  into the author's homedir. Run this with 'make testdistros'.

- svn add the new testdistro (first we did that, then we stopped doing
  it for "it makes no sense"; tehen I realized we need to do it
  because wit a newer MakeMaker or Moule::Build we cannot regenerate
  them byte-by-byte and lose the signature war)

- add it to the MANIFEST

(3) Upload and embed into our minicpan

- verify that 'make dist' on CPAN.pm still works

- if you want more distros, repeat (1) and (2) now

- upload the distro(s) to the CPAN and wait until the indexer has
  produced a CHECKSUMS file

- svn add/ci the relevant CHECKSUMS files

- add the CHECKSUMS files to the MANIFEST

(4) Work with the results

- verify that 'make dist' on CPAN.pm still works

- add the distro(s) to CPAN/modules/02packages.details.txt

- add the test to shell.t that triggered the demand for a new distro

