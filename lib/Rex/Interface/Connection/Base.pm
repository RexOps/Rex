#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Connection::Base;
   
use strict;
use warnings;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub connect { die("Must be implemented by Interface Class"); };
sub get_connection_object { die("Must be implemented by Interface Class"); };
sub is_connected { die("Must be implemented by Interface Class"); };
sub is_authenticated { die("Must be implemented by Interface Class"); };

1;
