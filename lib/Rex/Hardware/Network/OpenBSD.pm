#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Hardware::Network::OpenBSD;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Helper::Array;
use Rex::Hardware::Network::FreeBSD;

sub get_network_devices {

   return Rex::Hardware::Network::FreeBSD::get_network_devices();

}

sub get_network_configuration {

   return Rex::Hardware::Network::FreeBSD::get_network_configuration();
   
}

1;
