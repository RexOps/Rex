#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Inventory::Bios;

use v5.12.5;
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
