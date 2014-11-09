#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Inventory::SMBios::SystemInformation;

use warnings;

use Rex::Inventory::SMBios::Section;
use base qw(Rex::Inventory::SMBios::Section);

__PACKAGE__->section("system information");

__PACKAGE__->has(
  [
    'Manufacturer', { key => 'Product Name', from => "Product" },
    'UUID', 'SKU Number', 'Family', 'Version', 'Serial Number',
  ],
  1
);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

1;

