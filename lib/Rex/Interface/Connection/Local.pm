#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Connection::Local;
   
use strict;
use warnings;

use Rex::Interface::Connection::Base;

use base qw(Rex::Interface::Connection::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $that->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub error { };
sub connect { };
sub disconnect { };
sub get_connection_object { return $self; };
sub is_connected { return 1; };
sub is_authenticated { return 1; };

1;
