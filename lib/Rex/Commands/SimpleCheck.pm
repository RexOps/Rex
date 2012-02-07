#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Commands::SimpleCheck;
   
use strict;
use warnings;

use IO::Socket;
   
require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
    
@EXPORT = qw(is_port_open);
   
sub is_port_open {

   my ($ip, $port, $type) = @_;

   $type ||= "tcp";

   my $socket = IO::Socket::INET->new(PeerAddr => $ip,
                                PeerPort => $port,
                                Proto    => $type,
                                Timeout  => 2,
                                Type     => SOCK_STREAM);

   if($socket) {
      close $socket;
      return 1;
   }

   return 0;

}
   
1;
