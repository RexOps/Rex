#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Inventory::DMIDecode::MemoryArray;

use warnings;

use Rex::Inventory::DMIDecode::Section;
use base qw(Rex::Inventory::DMIDecode::Section);

__PACKAGE__->section("Physical Memory Array");

__PACKAGE__->has(
  [
    'Number Of Devices',
    'Error Correction Type',
    'Maximum Capacity',
    'Location',
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

