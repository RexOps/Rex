#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::Hal::Object::Volume;

use 5.010001;
use strict;
use warnings;
use Data::Dumper;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Inventory::Hal::Object;
use base qw(Rex::Inventory::Hal::Object);

__PACKAGE__->has(
  [

    { key => "block.device",  accessor => "dev", },
    { key => "volume.size",   accessor => "size", },
    { key => "volume.fstype", accessor => "fstype" },
    { key => "volume.uuid",   accessor => "uuid" },

  ]
);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub is_parition {

  my ($self) = @_;
  return $self->get('volume.is_partition') eq "true" ? 1 : 0;

}

sub is_mounted {

  my ($self) = @_;
  return $self->get('volume.is_mounted') eq "true" ? 1 : 0;

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

1;
