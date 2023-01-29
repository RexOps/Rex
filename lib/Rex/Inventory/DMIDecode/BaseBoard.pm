#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Inventory::DMIDecode::BaseBoard;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Inventory::DMIDecode::Section;
use base qw(Rex::Inventory::DMIDecode::Section);

__PACKAGE__->section("Base Board Information");

__PACKAGE__->has(
  [ 'Manufacturer', 'Serial Number', 'Version', 'Product Name', ] );

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

1;
