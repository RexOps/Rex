#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory::Hal::Object;

use strict;
use warnings;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}


# returns the parent of the current object
sub parent {

   my ($self) = @_;
   return $self->{"hal"}->get_object_by_udi($self->{'info.parent'});

}

sub get {

   my ($self, $key) = @_;

   if(ref($self->{$key}) eq "ARRAY") {
      return @{$self->{$key}};
   }

   return $self->{$key};

}

1;
