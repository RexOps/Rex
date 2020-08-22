#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::Hal::Object::Storage;

use strict;
use warnings;
use Data::Dumper;

# VERSION

use Rex::Inventory::Hal::Object;
use Rex::Commands::Gather;
use Rex::Commands::Run;

use base qw(Rex::Inventory::Hal::Object);

__PACKAGE__->has(
  [

    { key => "block.device", accessor => "dev", },

    { key => "storage.size", accessor => "size", overwrite => 1, },
    { key => "info.product",                      accessor => "product" },
    { key => [ "storage.vendor", "info.vendor" ], accessor => "vendor" },
    { key => "storage.bus",                       accessor => "bus" },

  ]
);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub is_cdrom {

  my ($self) = @_;
  if ( grep { /^storage\.cdrom$/ } $self->get('info.capabilities') ) {
    return 1;
  }

}

sub is_volume {

  my ($self) = @_;
  if ( grep { !/^false$/ } $self->get('block.is_volume') ) {
    return 1;
  }

}

sub is_floppy {

  my ($self) = @_;
  if ( grep { /^floppy$/ } $self->get('storage.drive_type') ) {
    return 1;
  }

}

sub get_size {

  my ($self) = @_;

  my $os = get_operating_system();

  if ( $os =~ m/BSD/ ) {
    my ($info_line) = run "diskinfo " . $self->get_dev;
    my ( $dev_name, $sector, $size, $sectors, $stripesize, $stripeoffset,
      $cylinders, $heads )
      = split( /\s+/, $info_line );

    return $size;
  }
  else {
    return $self->get("storage.size");
  }

}

1;
