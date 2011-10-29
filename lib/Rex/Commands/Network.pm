#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Network - Network Module

=head1 DESCRIPTION

With this module you can get information of the routing table, current network connections, open ports, ...

=head1 SYNOPSIS

 use Rex::Commands::Network;

 my @routes = route;
 print Dumper(\@routes);

 my $default_gw = default_gateway;
 default_gateway "192.168.2.1";

 my @netstat = netstat;
 my @tcp_connections = grep { $_->{"proto"} eq "tcp" } netstat;

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Network;

use strict;
use warnings;

require Exporter;
use Rex::Commands::Run;
use Rex::Commands::Gather;
use Rex::Hardware::Network;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(route default_gateway netstat);

=item route

Get routing information

=cut
sub route {
   return Rex::Hardware::Network::route();
}

=item default_gateway([$default_gw])

Get or set the default gateway.

=cut
sub default_gateway {
   return Rex::Hardware::Network::default_gateway();
}

=item netstat

Get network connection information

=cut
sub netstat {
   return Rex::Hardware::Network::netstat();
}

=back

=cut

1;
