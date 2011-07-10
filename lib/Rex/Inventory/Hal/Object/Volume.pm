#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory::Hal::Object::Volume;

use strict;
use warnings;
use Data::Dumper;

use Rex::Inventory::Hal::Object;
use base qw(Rex::Inventory::Hal::Object);

__PACKAGE__->has([

   { key => "block.device",  accessor => "dev", },
   { key => "volume.size",   accessor => "size", },
   { key => "volume.fstype", accessor => "fstype" },
   { key => "volume.uuid",   accessor => "uuid" },

]);



sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub is_parition {

   my ($self) = @_;
   return $self->get('volume.is_partition') eq "true"?1:0;

}

sub is_mounted {

   my ($self) = @_;
   return $self->get('volume.is_mounted') eq "true"?1:0;

}


1;
