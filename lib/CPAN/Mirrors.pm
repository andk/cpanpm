# -*- Mode: cperl; coding: utf-8; cperl-indent-level: 4 -*-
# vim: ts=4 sts=4 sw=4:
package CPAN::Mirrors;
use strict;
use vars qw($VERSION $urllist $silent);
$VERSION = "1";

use FileHandle;

sub new {
    my ($class, $file) = @_;
    my(%all,$host,
       $dst,$country,$continent,@location);
    my $fh = FileHandle->new;
    $fh->open($file) 
        or die "Couldn't open $file: $!";
    local $/ = "\012";
    while (<$fh>) {
        ($host) = /^([\w\.\-]+)/ unless defined $host;
        next unless defined $host;
        next unless /\s+dst_(dst|location)/;
        /location\s+=\s+\"([^\"]+)/ and @location = (split /\s*,\s*/, $1) and
            ($continent, $country) = @location[-1,-2];
        $continent =~ s/\s\(.*//;
        $continent =~ s/\W+$//; # if Jarkko doesn't know latitude/longitude
        /dst_dst\s+=\s+\"([^\"]+)/  and $dst = $1;
        next unless $host && $dst && $continent && $country;
        $all{$continent}{$country}{$dst} = CPAN::Mirrored::By->new($continent,$country,$dst);
        undef $host;
        $dst=$continent=$country="";
    }
    $fh->close;
    return bless \%all, $class;
}

package CPAN::Mirrored::By;
use strict;

sub new {
    my($self,@arg) = @_;
    bless [@arg], $self;
}
sub continent { shift->[0] }
sub country { shift->[1] }
sub url { shift->[2] }

