#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Hardware::Network::Darwin;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

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
