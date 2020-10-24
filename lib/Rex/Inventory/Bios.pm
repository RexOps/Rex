#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::Bios;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Hardware::Host;
use Rex::Logger;

use Rex::Inventory::SMBios;
use Rex::Inventory::DMIDecode;

sub get {

  if ( Rex::Hardware::Host::get_operating_system() eq "SunOS" ) {
    return Rex::Inventory::SMBios->new;
  }
  else {
    return Rex::Inventory::DMIDecode->new;
  }

}

1;
