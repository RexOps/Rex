#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::SimpleCheck - Simple tcp/alive checks

=head1 DESCRIPTION

With this module you can do simple tcp/alive checks.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 SYNOPSIS

 if(is_port_open($remote_host, $port)) {
   print "Port $port is open\n";
 }

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::SimpleCheck;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use IO::Socket;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(is_port_open);

=head2 is_port_open($ip, $port)

Check if something is listening on port $port of $ip.

=cut

sub is_port_open {

  my ( $ip, $port, $type ) = @_;

  $type ||= "tcp";

  my $socket = IO::Socket::INET->new(
    PeerAddr => $ip,
    PeerPort => $port,
    Proto    => $type,
    Timeout  => 2,
    Type     => SOCK_STREAM
  );

  if ($socket) {
    close $socket;
    return 1;
  }

  return 0;

}

1;
