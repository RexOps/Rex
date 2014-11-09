#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Inventory::SMBios::Memory;

use warnings;

use Rex::Inventory::SMBios::Section;
use base qw(Rex::Inventory::SMBios::Section);

__PACKAGE__->section("memory device");

__PACKAGE__->has(
  [
    { key => 'Type', from => "Memory Type" },
    'Speed', 'Size', 'Bank Locator', 'Form Factor',
    { key => 'Locator', from => "Device Locator" },
  ],
  1
);    # is_array 1

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

1;
