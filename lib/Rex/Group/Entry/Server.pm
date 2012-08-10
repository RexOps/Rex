#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Group::Entry::Server;
   
use strict;
use warnings;

use overload
   'eq' => sub { shift->is_eq(@_); },
   'ne' => sub { shift->is_ne(@_); },
   '""' => sub { shift->to_s(@_); };

use attributes;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub get_servers {
   my ($self) = @_;
   return map { $_ = Rex::Group::Entry::Server->new(name => $_, auth => $self->{auth}); } Rex::Commands::evaluate_hostname($self->to_s);
}

sub to_s {
   my ($self) = @_;
   return $self->{name};
}

sub is_eq {
   my ($self, $comp) = @_;
   if($comp eq $self->to_s) {
      return 1;
   }
}

sub is_ne {
   my ($self, $comp) = @_;
   if($comp ne $self->to_s) {
      return 1;
   }
}

sub has_auth {
   my ($self) = @_;
   return exists $self->{auth};
}

sub set_auth {
   my ($self, %auth) = @_;
   $self->{auth} = \%auth;
}

sub get_auth {
   my ($self) = @_;
   return $self->{auth};
}

sub get_user {
   my ($self) = @_;
   return $self->{auth}->{user};
}

sub get_password {
   my ($self) = @_;
   return $self->{auth}->{password};
}

sub get_public_key {
   my ($self) = @_;
   return $self->{auth}->{public_key};
}

sub get_private_key {
   my ($self) = @_;
   return $self->{auth}->{private_key};
}

1;
