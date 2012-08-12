#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Group::Entry::Server;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Config;

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

   if(exists $self->{auth}->{user}) {
      return $self->{auth}->{user};
   }

   if( ! Rex::Config->has_user && Rex::Config->get_ssh_config_username(server => $self->to_s) ) {
      Rex::Logger::debug("Checking for a user in .ssh/config");
      return Rex::Config->get_ssh_config_username(server => $self->to_s);
   }

   return Rex::Config->get_user;
}

sub get_password {
   my ($self) = @_;

   if(exists $self->{auth}->{password}) {
      return $self->{auth}->{password};
   }

   return Rex::Config->get_password;
}

sub get_public_key {
   my ($self) = @_;

   if(exists $self->{auth}->{public_key} && -f $self->{auth}->{public_key}) {
      return $self->{auth}->{public_key};
   }

   if( ! Rex::Config->has_public_key && Rex::Config->get_ssh_config_public_key(server => $self->to_s) ) {
      Rex::Logger::debug("Checking for a public key in .ssh/config");
      return Rex::Config->get_ssh_config_public_key(server => $self->to_s);
   }

   return Rex::Config->get_public_key;
}

sub get_private_key {
   my ($self) = @_;

   if(exists $self->{auth}->{private_key} && -f $self->{auth}->{public_key}) {
      return $self->{auth}->{private_key};
   }

   if( ! Rex::Config->has_private_key && Rex::Config->get_ssh_config_private_key(server => $self->to_s) ) {
      Rex::Logger::debug("Checking for a private key in .ssh/config");
      return Rex::Config->get_ssh_config_private_key(server => $self->to_s);
   }

   return Rex::Config->get_private_key;
}

sub get_auth_type {
   my ($self) = @_;

   if(exists $self->{auth}->{auth_type} && $self->{auth}->{auth_type}) {
      return $self->{auth}->{auth_type};
   }

   if(exists $self->{auth}->{public_key} &&  -f $self->{auth}->{public_key}
         && exists $self->{auth}->{private_key} &&  -f $self->{auth}->{private_key}) {
      return "try";
   }
   elsif(exists $self->{auth}->{user} && $self->{auth}->{user}
         && exists $self->{auth}->{password} && $self->{auth}->{password} ne "") {
      return "try";
   }
   elsif(Rex::Config->get_password_auth) {
      return "pass";
   }
   elsif(Rex::Config->get_key_auth) {
      return "key";
   }

   return "try";
}

sub get_sudo {
   my ($self) = @_;
   if(exists $self->{auth}->{sudo}) {
      return $self->{auth}->{sudo};
   }

   return 0;
}

sub get_sudo_password {
   my ($self) = @_;
   if(exists $self->{auth}->{sudo_password}) {
      return $self->{auth}->{sudo_password};
   }

   Rex::Config->get_sudo_password;
}



sub merge_auth {
   my ($self, $other_auth) = @_;

   my %new_auth;
   my @keys = qw/user password private_key public_key auth_type sudo sudo_password/;

   for my $key (@keys) {
      my $call = "get_$key";
      if(ref($self)->can($call)) {
         $new_auth{$key} = $self->$call();
      }
      else {
         $new_auth{$key} = $other_auth->{$key};
      }

      # other_auth has presedence
      if(exists $other_auth->{$key}) {
         $new_auth{$key} = $other_auth->{$key};
      }
   }

   return %new_auth;
}


1;
