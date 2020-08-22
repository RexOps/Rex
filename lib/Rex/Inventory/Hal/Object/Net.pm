#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::Hal::Object::Net;

use strict;
use warnings;

# VERSION

use Rex::Inventory::Hal::Object;
use base qw(Rex::Inventory::Hal::Object);

__PACKAGE__->has(
  [

    { key => "net.interface", accessor => "dev", },
    { key => "net.address",   accessor => "mac", },
    { key => "info.product",  accessor => "product", parent => 1, },
    { key => "info.vendor",   accessor => "vendor",  parent => 1, },

  ]
);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

1;
