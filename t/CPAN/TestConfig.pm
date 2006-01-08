use Cwd;
my $cwd = cwd;
$CPAN::Config = {
                 'build_cache' => q[100],
                 'build_dir' => qq[$cwd/dot-cpan/build],
                 'bzip2' => q[/bin/bzip2],
                 'cache_metadata' => q[1],
                 'cpan_home' => qq[$cwd/dot-cpan],
                 'curl' => q[],
                 # 'dontload_hash' => { Net::FTP => 1 },
                 'ftp' => q[],
                 'ftp_proxy' => q[],
                 'getcwd' => q[cwd],
                 'gpg' => q[/usr/bin/gpg],
                 'gzip' => q[/bin/gzip],
                 'histfile' => qq[$cwd/dot-cpan/histfile],
                 'histsize' => q[100],
                 'http_proxy' => q[],
                 'inactivity_timeout' => q[0],
                 'index_expire' => q[1],
                 'inhibit_startup_message' => q[0],
                 'keep_source_where' => qq[$cwd/dot-cpan/sources],
                 'lynx' => q[],
                 'make' => q[/usr/bin/make],
                 'make_arg' => q[],
                 'make_install_arg' => q[UNINST=1],
                 'make_install_make_command' => q[sudo make],
                 'makepl_arg' => q[],
                 'mbuild_arg' => q[],
                 'mbuild_install_arg' => q[--uninst 1],
                 'mbuild_install_build_command' => q[sudo ./Build],
                 'mbuildpl_arg' => q[],
                 'ncftp' => q[],
                 'ncftpget' => q[],
                 'no_proxy' => q[],
                 'pager' => q[less],
                 'prefer_installer' => q[MB],
                 'prerequisites_policy' => q[follow],
                 'scan_cache' => q[atstart],
                 'shell' => q[/usr/bin/zsh],
                 'show_upload_date' => q[1],
                 'tar' => q[/bin/tar],
                 'term_is_latin' => q[0],
                 'unzip' => q[/usr/bin/unzip],
                 'urllist' => [q[ftp://localhost/pub/CPAN]],
                 'wait_list' => [q[wait://ls6.informatik.uni-dortmund.de:1404]],
                 'wg' => q[],
                 'wget' => q[/usr/bin/wget],
                };

__END__

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
