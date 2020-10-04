#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Group::Entry::Server;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::System;
use Rex::Config;
use Rex::Interface::Exec;
use Data::Dumper;
use Sort::Naturally;
use Symbol;

use List::MoreUtils 0.416 qw(uniq);

use overload
  'eq'  => sub { shift->is_eq(@_); },
  'ne'  => sub { shift->is_ne(@_); },
  '""'  => sub { shift->to_s(@_); },
  'cmp' => sub { shift->compare(@_); };

use attributes;

sub function {
  my ( $class, $name, $code ) = @_;

  my $ref_to_function = qualify_to_ref( $name, $class );
  *{$ref_to_function} = $code;
}

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  # be save check if name is already a server ref
  if ( ref $self->{name} eq __PACKAGE__ ) {
    return $self->{name};
  }

  # rewrite auth info
  if ( $self->{user} ) {
    $self->{auth}->{user} = $self->{user};
    delete $self->{user};
  }

  if ( $self->{password} ) {
    $self->{auth}->{password} = $self->{password};
    delete $self->{password};
  }

  if ( $self->{port} ) {
    $self->{auth}->{port} = $self->{port};
    delete $self->{port};
  }

  if ( $self->{public_key} ) {
    $self->{auth}->{public_key} = $self->{public_key};
    delete $self->{public_key};
  }

  if ( $self->{private_key} ) {
    $self->{auth}->{private_key} = $self->{private_key};
    delete $self->{private_key};
  }

  if ( $self->{sudo} ) {
    $self->{auth}->{sudo} = $self->{sudo};
    delete $self->{sudo};
  }

  if ( $self->{sudo_password} ) {
    $self->{auth}->{sudo_password} = $self->{sudo_password};
    delete $self->{sudo_password};
  }

  if ( $self->{auth_type} ) {
    $self->{auth}->{auth_type} = $self->{auth_type};
    delete $self->{auth_type};
  }

  if ( !ref $self->{__group__} ) {
    $self->{__group__} = [];
  }

  return $self;
}

sub get_servers {
  my ($self) = @_;
  return uniq map {
    if ( ref $_ && $_->isa("Rex::Group::Entry::Server") ) {
      $_;
    }
    else {
      Rex::Group::Entry::Server->new( name => $_, auth => $self->{auth} );
    }
  } $self->evaluate_hostname;
}

sub to_s {
  my ($self) = @_;
  return $self->{name};
}

sub is_eq {
  my ( $self, $comp ) = @_;
  if ( $comp eq $self->to_s ) {
    return 1;
  }
}

sub is_ne {
  my ( $self, $comp ) = @_;
  if ( $comp ne $self->to_s ) {
    return 1;
  }
}

sub compare {
  my ( $self, $comp ) = @_;
  return ncmp( $self->to_s, $comp->to_s );
}

sub has_auth {
  my ($self) = @_;
  return exists $self->{auth};
}

sub set_auth {
  my ( $self, %auth ) = @_;
  $self->{auth} = \%auth;
}

sub get_auth {
  my ($self) = @_;
  return $self->{auth};
}

sub get_user {
  my ($self) = @_;

  if ( exists $self->{auth}->{user} ) {
    return $self->{auth}->{user};
  }

  if (!Rex::Config->has_user
    && Rex::Config->get_ssh_config_username( server => $self->to_s ) )
  {
    Rex::Logger::debug("Checking for a user in .ssh/config");
    return Rex::Config->get_ssh_config_username( server => $self->to_s );
  }

  return Rex::Config->get_user;
}

sub get_password {
  my ($self) = @_;

  if ( exists $self->{auth}->{password} ) {
    return $self->{auth}->{password};
  }

  return Rex::Config->get_password;
}

sub get_port {
  my ($self) = @_;

  if ( exists $self->{auth}->{port} ) {
    return $self->{auth}->{port};
  }

  return Rex::Config->get_port;
}

sub get_public_key {
  my ($self) = @_;

  if ( exists $self->{auth}->{public_key} && -f $self->{auth}->{public_key} ) {
    Rex::Logger::debug(
      "Rex::Group::Entry::Server (public_key): returning $self->{auth}->{public_key}"
    );
    return $self->{auth}->{public_key};
  }

  if (!Rex::Config->has_public_key
    && Rex::Config->get_ssh_config_public_key( server => $self->to_s ) )
  {
    Rex::Logger::debug("Checking for a public key in .ssh/config");
    my $key = Rex::Config->get_ssh_config_public_key( server => $self->to_s );
    Rex::Logger::debug(
      "Rex::Group::Entry::Server (public_key): returning $key");
    return $key;
  }

  Rex::Logger::debug( "Rex::Group::Entry::Server (public_key): returning "
      . ( Rex::Config->get_public_key || "" ) );
  return Rex::Config->get_public_key;
}

sub get_private_key {
  my ($self) = @_;

  if ( exists $self->{auth}->{private_key} && -f $self->{auth}->{private_key} )
  {
    Rex::Logger::debug( "Rex::Group::Entry::Server (private_key): returning "
        . $self->{auth}->{private_key} );
    return $self->{auth}->{private_key};
  }

  if (!Rex::Config->has_private_key
    && Rex::Config->get_ssh_config_private_key( server => $self->to_s ) )
  {
    Rex::Logger::debug("Checking for a private key in .ssh/config");
    my $key = Rex::Config->get_ssh_config_private_key( server => $self->to_s );
    Rex::Logger::debug(
      "Rex::Group::Entry::Server (private_key): returning " . $key );
    return $key;
  }

  Rex::Logger::debug( "Rex::Group::Entry::Server (private_key): returning "
      . ( Rex::Config->get_private_key || "" ) );
  return Rex::Config->get_private_key;
}

sub get_auth_type {
  my ($self) = @_;

  if ( exists $self->{auth}->{auth_type} && $self->{auth}->{auth_type} ) {
    return $self->{auth}->{auth_type};
  }

  if ( exists $self->{auth}->{public_key}
    && -f $self->{auth}->{public_key}
    && exists $self->{auth}->{private_key}
    && -f $self->{auth}->{private_key} )
  {
    return "try";
  }
  elsif ( exists $self->{auth}->{user}
    && $self->{auth}->{user}
    && exists $self->{auth}->{password}
    && $self->{auth}->{password} ne "" )
  {
    return "try";
  }
  elsif ( Rex::Config->get_krb5_auth ) {
    return "krb5";
  }
  elsif ( Rex::Config->get_password_auth ) {
    return "pass";
  }
  elsif ( Rex::Config->get_key_auth ) {
    return "key";
  }

  return "try";
}

sub get_sudo {
  my ($self) = @_;
  if ( exists $self->{auth}->{sudo} ) {
    return $self->{auth}->{sudo};
  }

  return 0;
}

sub get_sudo_password {
  my ($self) = @_;
  if ( exists $self->{auth}->{sudo_password} ) {
    return $self->{auth}->{sudo_password};
  }

  Rex::Config->get_sudo_password;
}

sub merge_auth {
  my ( $self, $other_auth ) = @_;

  my %new_auth;
  my @keys =
    qw/user password port private_key public_key auth_type sudo sudo_password/;

  for my $key (@keys) {
    my $call = "get_$key";
    if ( ref($self)->can($call) ) {
      $new_auth{$key} = $self->$call();
    }
    else {
      $new_auth{$key} = $other_auth->{$key};
    }

    # other_auth has presedence
    if ( exists $other_auth->{$key}
      && defined $other_auth->{$key}
      && Rex::Config->get_use_server_auth() == 0 )
    {
      $new_auth{$key} = $other_auth->{$key};
    }
  }

  return %new_auth;
}

sub append_to_group {
  my ( $self, $group ) = @_;
  push @{ $self->{__group__} }, $group;
}

sub group {
  my ($self) = @_;
  return $self->groups;
}

sub groups {
  my ($self) = @_;
  return @{ $self->{__group__} };
}

sub option {
  my ( $self, $option ) = @_;
  if ( exists $self->{$option} ) {
    return $self->{$option};
  }
}

sub gather_information {
  my ($self) = @_;
  my %info = Rex::Helper::System::info();
  $self->{__hardware_info__} = \%info;
}

sub AUTOLOAD {
  use vars qw($AUTOLOAD);
  my $self = shift;

  return $self if ( $AUTOLOAD =~ m/DESTROY/ );

  my ($wanted_data) = ( $AUTOLOAD =~ m/::([a-z0-9A-Z_]+)$/ );

  if ( scalar( keys %{ $self->{__hardware_info__} } ) == 0 ) {
    $self->gather_information;
  }

  if ( exists $self->{__hardware_info__}->{$wanted_data} ) {
    return $self->{__hardware_info__}->{$wanted_data};
  }

  if ( exists $self->{$wanted_data} ) {
    return $self->{$wanted_data};
  }

  return;
}

sub evaluate_hostname {
  my ($self) = @_;

  my @servers = Rex::Commands::evaluate_hostname( $self->to_s );
  my @multiple_me;

  for (@servers) {
    push @multiple_me, ref($self)->new( %{$self} );
    $multiple_me[-1]->{name} = $_;
  }

  return @multiple_me;
}

sub test_perl {
  my ($self) = @_;
  my $exec = Rex::Interface::Exec->create;
  return $exec->can_run( ["perl"] ); # use a new anon ref, so that we don't have drawbacks if some lower layers will manipulate things.
}

1;
