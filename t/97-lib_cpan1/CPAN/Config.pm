use strict;

use Carp qw(croak);
use Cwd;
use File::Spec::Functions qw(catfile);

my $cwd = cwd();

my $test_mirror_directory = catfile( qw( t 97-cpan1-test-mirror ) );

my $am_at_distro_root = -d $test_mirror_directory;
croak "Did not find $test_mirror_directory in the current working directory!\n"
	unless $am_at_distro_root;

my $cpan_home = catfile( $cwd, 'cpan-home' );
mkdir $cpan_home, 0755 unless -d $cpan_home;
croak "Did not find $cpan_home in the current working directory!\n"
	unless -d $cpan_home;

$CPAN::Config = {
                  'auto_commit' => '1',
                  'build_cache' => '10',
                  'build_dir' => catfile( $cpan_home, 'build' ),
                  'bzip2' => '',
                  'cache_metadata' => '1',
                  'check_sigs' => '0',
                  'colorize_output' => '0',
                  'commandnumber_in_prompt' => '1',
				  'connect_to_internet_ok' => '0',
				  'cpan_home' => $cpan_home,
                  'curl' => '',
                  'dontload_hash' => {},
                  'ftp_passive' => '1',
                  'ftp_proxy' => '',
                  'ftp' => '',
                  'getcwd' => 'cwd',
                  'gpg' => '',
                  'gzip' => '',
                  'histfile' => catfile( $cpan_home, 'histfile' ),
                  'histsize' => '100',
                  'http_proxy' => '',
                  'inactivity_timeout' => '0',
                  'index_expire' => '1',
                  'inhibit_startup_message' => '0',
                  'keep_source_where' => catfile( $cpan_home, 'sources' ),
                  'lynx' => '',
                  'make_arg' => '',
                  'make_install_arg' => "",
                  'make_install_make_command' => '',
                  'make' => '',
                  'makepl_arg' => "INSTALL_BASE=$cpan_home",
                  'mbuild_arg' => "--install_base=$cpan_home",
                  'mbuild_install_arg' => "",
                  'mbuild_install_build_command' => './Build',
                  'mbuildpl_arg' => '',
                  'ncftp' => '',
                  'ncftpget' => '',
                  'no_proxy' => '',
                  'pager' => '',
                  'prefer_installer' => 'EUMM',
                  'prerequisites_policy' => 'follow',
                  'scan_cache' => 'atstart',
                  'shell' => '',
                  'show_upload_date' => '1',
                  'tar' => '',
                  'term_is_latin' => '1',
                  'term_ornaments' => '1',
                  'test_report' => '0',
                  'unzip' => '',
                  'urllist' => [
                  	"file://$cwd/$test_mirror_directory"
                  	],
                  'use_sqlite' => '0',
                  'wget' => '',
                };

1;
__END__
