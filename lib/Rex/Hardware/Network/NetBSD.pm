#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hardware::Network::NetBSD;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Array;
use Rex::Hardware::Network::OpenBSD;

sub get_network_devices {

  return Rex::Hardware::Network::OpenBSD::get_network_devices();

}

sub get_network_configuration {

  return Rex::Hardware::Network::OpenBSD::get_network_configuration();

}

sub route {
  return Rex::Hardware::Network::OpenBSD->route();
}

sub default_gateway {
  shift;
  return Rex::Hardware::Network::OpenBSD->default_gateway(@_);
}

sub netstat {
  return Rex::Hardware::Network::OpenBSD->netstat();
}

1;
