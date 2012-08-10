#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Connection::Local;
   
use strict;
use warnings;

use Rex::Interface::Connection::Base;
use Rex::Group::Entry::Server;

use base qw(Rex::Interface::Connection::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $that->SUPER::new(@_);

   $self->{server} = Rex::Group::Entry::Server->new(name => "<local>");

   bless($self, $proto);

   return $self;
}

sub error { };
sub connect { };
sub disconnect { };
sub get_connection_object { my ($self) = @_; return $self; };
sub get_fs_connection_object { my ($self) = @_; return $self; };
sub is_connected { return 1; };
sub is_authenticated { return 1; };

sub get_connection_type { return "Local"; }

1;
