use strict;
use warnings;

use RT::Client::REST;
use Getopt::Long;

my %Config = (
              server      => 'http://rt.cpan.org',
              username    => 'ANDK',
              password    => '',
             );

GetOptions(\my %config, map { "$_=s" } keys %Config);
while (my($k,$v) = each %config) {
  $Config{$k} = $v;
}

my $rt = RT::Client::REST->new(
                               server  => $Config{server},
                               timeout => 300
                              );

eval { $rt->login( username => $Config{username}, password => $Config{password} ); };
die "problem logging in: '$@'" if $@;

my @ids;
eval {
  @ids = $rt->search(
                     type    => 'ticket',
                     query   => qq[
            (Status = 'new' or Status = 'open')
        ],
                     orderby => 'CustomField.{Severity}'
                    );
};
die "search failed: $@" if $@;

for my $id (@ids) {
  my $ticket = $rt->show(type => 'ticket', id => $id);
  print "ID: $id\n";
  print "\tSubject: ", $ticket->{Subject}, "\n";
  print "\tSeverity: ", $ticket->{"CF-Severity"}, "\n";
}
