#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::DMIDecode::Memory;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Inventory::DMIDecode::Section;
use base qw(Rex::Inventory::DMIDecode::Section);

__PACKAGE__->section("Memory Device");

__PACKAGE__->has(
  [
    'Part Number', 'Serial Number', 'Type',         'Speed',
    'Size',        'Manufacturer',  'Bank Locator', 'Form Factor',
    'Locator',
  ],
  1
); # is_array 1

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub get {

  my ( $self, $key, $is_array ) = @_;
  if ( $key eq "Type" ) {
    my $ret = $self->_search_for( $key, $is_array );
    if ( $ret eq "<OUT OF SPEC>" ) {
      return "";
    }

    return $ret;
  }

  return $self->SUPER::get( $key, $is_array );

}

1;

