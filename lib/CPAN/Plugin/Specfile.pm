package CPAN::Plugin::Specfile;

use File::Path;
use File::Spec;

sub __accessor {
    my ($class, $key) = @_;
    no strict 'refs';
    *{$class . '::' . $key} = sub {
        my $self = shift;
        if (@_) {
            $self->{$key} = shift;
        }
        return $self->{$key};
    };
}
BEGIN { __PACKAGE__->__accessor($_) for qw(dir dir_default) }

sub new {
    my($class, @rest) = @_;
    my $self = bless {}, $class;
    while (my($arg,$val) = splice @rest, 0, 2) {
        $self->$arg($val);
    }
    $self->dir_default(File::Spec->catdir($CPAN::Config->{cpan_home},"plugins",__PACKAGE__));
    $self;
}

sub post_test {
    my $self = shift;
    my $distribution_object = shift;
    my $distribution = $distribution_object->id;
    unless ($CPAN::META->has_inst("CPAN::DistnameInfo")){
        $CPAN::Frontend->mydie("CPAN::DistnameInfo not installed; cannot continue");
    }
    my $d = CPAN::Shell->expand("Distribution",$distribution)
        or $CPAN::Frontend->mydie("Unknowns distribution '$distribution'\n");
    my $build_dir = $d->{build_dir} or $CPAN::Frontend->mydie("Distribution has not been built yet, cannot proceed");
    my %contains = map {($_ => undef)} $d->containsmods;
    my @m;
    my $width = 16;
    my $header = sub {
        my($header,$value) = @_;
        push @m, sprintf("%-s:%*s%s\n", $header, $width-length($header), "", $value);
    };
    my $dni = CPAN::DistnameInfo->new($distribution);
    my $dist = $dni->dist;
    my $summary = CPAN::Shell->_guess_manpage($d,\%contains,$dist);
    $header->("Name", "perl-$dist");
    my $version = $dni->version;
    $header->("Version", $version);
    $header->("Release", "1%{?dist}");
#Summary:        Template processing system
#Group:          Development/Libraries
#License:        GPL+ or Artistic
#URL:            http://www.template-toolkit.org/
#Source0:        http://search.cpan.org/CPAN/authors/id/A/AB/ABW/Template-Toolkit-%{version}.tar.gz
#Patch0:         Template-2.22-SREZIC-01.patch
#BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
    for my $h_tuple
        ([Summary    => $summary],
         [Group      => "Development/Libraries"],
         [License    =>],
         [URL        =>],
         [BuildRoot  => "%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)"],
         [Requires   => "perl(:MODULE_COMPAT_%(eval \"`%{__perl} -V:version`\"; echo \$version))"],
        ) {
        my($h,$v) = @$h_tuple;
        $v = "unknown" unless defined $v;
        $header->($h, $v);
    }
    $header->("Source0", sprintf(
                                 "http://search.cpan.org/CPAN/authors/id/%s/%s/%s",
                                 substr($distribution,0,1),
                                 substr($distribution,0,2),
                                 $distribution
                                ));
    require POSIX;
    my @xs = glob "$build_dir/*.xs"; # quick try
    unless (@xs) {
        require ExtUtils::Manifest;
        my $manifest_file = "$build_dir/MANIFEST";
        my $manifest = ExtUtils::Manifest::maniread($manifest_file);
        @xs = grep /\.xs$/, keys %$manifest;
    }
    if (! @xs) {
        $header->('BuildArch', 'noarch');
    }
    for my $k (sort keys %contains) {
        my $m = CPAN::Shell->expand("Module",$k);
        my $v = $contains{$k} = $m->cpan_version;
        my $vspec = $v eq "undef" ? "" : " = $v";
        $header->("Provides", "perl($k)$vspec");
    }
    if (my $prereq_pm = $d->{prereq_pm}) {
        my %req;
        for my $reqkey (keys %$prereq_pm) {
            while (my($k,$v) = each %{$prereq_pm->{$reqkey}}) {
                $req{$k} = $v;
            }
        }
        if (-e "$build_dir/Build.PL" && ! exists $req{"Module::Build"}) {
            $req{"Module::Build"} = 0;
        }
        for my $k (sort keys %req) {
            next if $k eq "perl";
            my $v = $req{$k};
            my $vspec = defined $v && length $v && $v > 0 ? " >= $v" : "";
            $header->(BuildRequires => "perl($k)$vspec");
            next if $k =~ /^(Module::Build)$/; # MB is always only a
                                               # BuildRequires; if we
                                               # turn it into a
                                               # Requires, then we
                                               # would have to make it
                                               # a BuildRequires
                                               # everywhere we depend
                                               # on *one* MB built
                                               # module.
            $header->(Requires => "perl($k)$vspec");
        }
    }
    push @m, "\n%define _use_internal_dependency_generator     0
%define __find_requires %{nil}
%define __find_provides %{nil}
";
    push @m, "\n%description\n%{summary}.\n";
    push @m, "\n%prep\n%setup -q -n $dist-%{version}\n";
    if (-e "$build_dir/Build.PL") {
        # see http://www.redhat.com/archives/rpm-list/2002-July/msg00110.html about RPM_BUILD_ROOT vs %{buildroot}
        push @m, <<'EOF';

%build
%{__perl} Build.PL --installdirs=vendor --libdoc installvendorman3dir
./Build

%install
rm -rf $RPM_BUILD_ROOT
./Build install destdir=$RPM_BUILD_ROOT create_packlist=0
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*

%check
./Build test
EOF
    } elsif (-e "$build_dir/Makefile.PL") {
        push @m, <<'EOF';

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT
make pure_install DESTDIR=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} ';'
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null ';'
%{_fixperms} $RPM_BUILD_ROOT/*

%check
make test
EOF
    } else {
        $CPAN::Frontend->mydie("'$distribution' has neither a Build.PL nor a Makefile.PL\n");
    }
    push @m, "\n%clean\nrm -rf \$RPM_BUILD_ROOT\n";
    my $vendorlib = @xs ? "vendorarch" : "vendorlib";
    my $date = POSIX::strftime("%a %b %d %Y", gmtime);
    my @doc = grep { -e "$build_dir/$_" } qw(README Changes);
    my $exe_stanza = "\n";
    if (my $exe_files = $d->_exe_files) {
        if (@$exe_files) {
            $exe_stanza = "%{_mandir}/man1/*.1*\n";
            for my $e (@$exe_files) {
                unless (CPAN->has_inst("File::Basename")) {
                    $CPAN::Frontend->mydie("File::Basename not installed, cannot continue");
                }
                my $basename = File::Basename::basename($e);
                $exe_stanza .= "/usr/bin/$basename\n";
            }
        }
    }
    push @m, <<EOF;

%files
%defattr(-,root,root,-)
%doc @doc
%{perl_$vendorlib}/*
%{_mandir}/man3/*.3*
$exe_stanza
%changelog
* $date  <akoenig\@specfile.cpan.org> - $version-1
- autogenerated by _specfile() in CPAN.pm

EOF

    my $ret = join "", @m;
    $CPAN::Frontend->myprint($ret);
    File::Path::mkpath($self->dir);
    my $outfile = File::Spec->catfile($self->dir, "perl-$dist.spec");
    open my $specout, ">", $outfile
        or $CPAN::Frontend->mydie("Could not open >$outfile: $!");
    print $specout $ret;
    $CPAN::Frontend->myprint("Wrote $outfile");
    $ret;
}

1;
