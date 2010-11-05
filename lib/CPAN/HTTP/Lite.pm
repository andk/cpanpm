# -*- Mode: cperl; coding: utf-8; cperl-indent-level: 4 -*-
# vim: ts=4 sts=4 sw=4:
package CPAN::HTTP::Lite;
use strict;
use vars qw(@ISA);
use HTTP::Lite 2.2;

$CPAN::HTTP::Lite::VERSION = $CPAN::HTTP::Lite::VERSION = "1.94";

# CPAN::HTTP::Lite is adapted from parts of cpanm by Tatsuhiko Miyagawa
# and parts of LWP by Gisle Aas

sub new {
    my $class = shift;
    my %args = @_;
    for my $k ( keys %args ) {
        $args{$k} = '' unless defined $args{$k};
    }
    $args{no_proxy} = [split(",", $args{no_proxy}) ] if $args{no_proxy};
    return bless \%args, $class;
}

# This executes a request with redirection (up to 5) and returns the HTTP::Lite
# object
#
# Because repeat requests could be made, it is passed a callback generator
# rather than callbacks.  The callback generator must return two functions, a
# 'data' callback as defined by HTTP::Lite, called on each chunk of data, and a
# 'done' function, called when the request is completed and given the
# HTTP::Lite request object.  Note that 'done' is handled here, not given to
# HTTP::Lite.

sub get {
    my($self, $uri, $cb_gen) = @_;

    my $http = HTTP::Lite->new;
    $http->http11_mode(1); # hopefully, CPAN mirrors can handle this

    my $retries = 0;
    while ( $retries++ < 5 ) {
        my $rc = $self->_make_request( $http, $uri, $cb_gen );
        if ( $rc == 401 ) {
            last unless $self->_prepare_auth( $http, 'non_proxy' );
        }
        elsif ( $rc == 407 ) {
            last unless $self->_prepare_auth( $http, 'proxy' );
        }
        elsif ( $rc == 301 || $rc == 302 ) {
            $uri = $self->_get_redirect( $http, $uri );
        }
        else {
            last;
        }
    }

    return $http;
}

sub mirror {
    my($self, $uri, $path) = @_;

    my $cb_gen = sub {
        open my $out, ">$path" or die "$path: $!";
        binmode $out;
        sub { print $out ${$_[1]} }, sub { close $out };
    };

    return $self->get($uri, $cb_gen);
};

sub _make_request {
    my ($self, $http, $uri, $cb_gen) = @_;
    $http->reset;
    if ( $self->_want_proxy($uri) ) {
        $http->proxy($self->{proxy});
        $self->_set_auth_headers( $http, $uri, 'proxy' );
    }
    $self->_set_auth_headers( $http, $uri, 'non_proxy' );
    my($data_cb, $done_cb) = $cb_gen ? $cb_gen->() : ();
    my $rc = $http->request($uri, $data_cb);
    $done_cb->($http) if $done_cb;
    $rc = 0 unless defined $rc;
    return $rc;
}

sub _want_proxy {
    my ($self, $uri) = @_;
    return unless $self->{proxy};
    my($host) = $uri =~ m|://([^/:]+)|;
    return ! grep { $host =~ /\Q$_\E$/ } @{ $self->{no_proxy} || [] };
}

sub _get_redirect {
    my ($self, $http, $uri) = @_;
    # figure out redirection
    my $loc;
    for ($http->headers_array) {
        /Location: (\S+)/ and $loc = $1, last;
    }
    $loc or return;
    if ($loc =~ m!^/!) {
        $uri =~ s{^(\w+?://[^/]+)/.*$}{$1};
        $uri .= $loc;
    } else {
        $uri = $loc;
    }
    return $uri;
}

sub _prepare_auth {
    my ($self, $http, $mode) = @_;
    my $prefix = $mode eq 'proxy' ? 'Proxy' : 'WWW';
    my ($type_key, $param_key) = map {"_" . $mode . $_} qw/_type _params/;
    if ( $self->{$param_key} ) { # had auth info and still failed
        my $method = "clear_${mode}_credentials";
        CPAN::HTTP::Credentials->$method;
    }
    ($self->{$type_key}, $self->{$param_key}) =
        $self->_get_auth_params( $http, "${prefix}-Authenticate");
    return $self->{$type_key};
}

sub _set_auth_headers {
    my ($self, $http, $uri, $mode) = @_;
    my ($type_key, $param_key) = map {"_" . $mode . $_} qw/_type _params/;
    return unless $self->{$type_key};
    my ($user, $pass) = $self->get_basic_credentials($mode);
    my $method = "_" . $self->{$type_key} . "_auth";
    my $value = $self->$method($user, $pass, $self->{$param_key}, $uri);
    my $header = $mode eq 'proxy' ? 'Proxy-Authorization' : 'Authorization';
    return $http->add_req_header( $header, $value );
}

sub _get_auth_params {
    my ($self, $http, $auth_header) = @_;

    my $headers = $http->get_header($auth_header);
    unless (@$headers) {
        return;
    }

    for my $challenge (@$headers) {
        $challenge =~ tr/,/;/;  # "," is used to separate auth-params!!
        ($challenge) = $self->split_header_words($challenge);
        my $scheme = shift(@$challenge);
        shift(@$challenge); # no value
        $challenge = { @$challenge };  # make rest into a hash

        unless ($scheme =~ /^(basic|digest)$/) {
            next; # bad scheme
        }
        $scheme = $1;  # untainted now

        return ($scheme, $challenge);
    }
    return;
}

sub _basic_auth {
    my ($self, $user, $pass) = @_;
    eval "require MIME::Base64" or return;
    return "Basic " . MIME::Base64::encode_base64("$user\:$pass", q{});
}

sub _digest_auth {
    my ($self, $user, $pass, $auth_param, $uri) = @_;
    eval "require Digest::MD5" or return;

    my $nc = sprintf "%08X", ++$self->{_nonce_count}{$auth_param->{nonce}};
    my $cnonce = sprintf "%8x", time;

    my ($path) = $uri =~ m{^\w+?://[^/]+(/.*)$};
    $path = "/" unless defined $path;

    my $md5 = Digest::MD5->new;

    my(@digest);
    $md5->add(join(":", $user, $auth_param->{realm}, $pass));
    push(@digest, $md5->hexdigest);
    $md5->reset;

    push(@digest, $auth_param->{nonce});

    if ($auth_param->{qop}) {
        push(@digest, $nc, $cnonce, ($auth_param->{qop} =~ m|^auth[,;]auth-int$|) ? 'auth' : $auth_param->{qop});
    }

    $md5->add(join(":", 'GET', $path));
    push(@digest, $md5->hexdigest);
    $md5->reset;

    $md5->add(join(":", @digest));
    my($digest) = $md5->hexdigest;
    $md5->reset;

    my %resp = map { $_ => $auth_param->{$_} } qw(realm nonce opaque);
    @resp{qw(username uri response algorithm)} = ($user, $path, $digest, "MD5");

    if (($auth_param->{qop} || "") =~ m|^auth([,;]auth-int)?$|) {
        @resp{qw(qop cnonce nc)} = ("auth", $cnonce, $nc);
    }

    my(@order) =
        qw(username realm qop algorithm uri nonce nc cnonce response opaque);
    my @pairs;
    for (@order) {
        next unless defined $resp{$_};
        push(@pairs, "$_=" . qq("$resp{$_}"));
    }

    my $auth_value  = "Digest " . join(", ", @pairs);
    return $auth_value;
}

sub get_basic_credentials {
    my ($self, $proxy ) = @_;
    my $method = "get_" . ($proxy ? "proxy" : "non_proxy") ."_credentials";
    return CPAN::HTTP::Credentials->$method;
}

# split_header_words adapted from HTTP::Headers::Util
sub split_header_words {
    my ($self, @words) = @_;
    my @res = $self->_split_header_words(@words);
    for my $arr (@res) {
        for (my $i = @$arr - 2; $i >= 0; $i -= 2) {
            $arr->[$i] = lc($arr->[$i]);
        }
    }
    return @res;
}

sub _split_header_words {
    my($self, @val) = @_;
    my @res;
    for (@val) {
        my @cur;
        while (length) {
            if (s/^\s*(=*[^\s=;,]+)//) {  # 'token' or parameter 'attribute'
                push(@cur, $1);
                # a quoted value
                if (s/^\s*=\s*\"([^\"\\]*(?:\\.[^\"\\]*)*)\"//) {
                    my $val = $1;
                    $val =~ s/\\(.)/$1/g;
                    push(@cur, $val);
                    # some unquoted value
                }
                elsif (s/^\s*=\s*([^;,\s]*)//) {
                    my $val = $1;
                    $val =~ s/\s+$//;
                    push(@cur, $val);
                    # no value, a lone token
                }
                else {
                    push(@cur, undef);
                }
            }
            elsif (s/^\s*,//) {
                push(@res, [@cur]) if @cur;
                @cur = ();
            }
            elsif (s/^\s*;// || s/^\s+//) {
                # continue
            }
            else {
                die "This should not happen: '$_'";
            }
        }
        push(@res, \@cur) if @cur;
    }
    @res;
}

1;
