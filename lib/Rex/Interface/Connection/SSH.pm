#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Connection::SSH;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  use Rex::Require;
  Net::SSH2->require;
}

use Carp;
use Rex::Helper::IP;
use Rex::Interface::Connection::Base;
use base qw(Rex::Interface::Connection::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub connect {
  my ( $self, %option ) = @_;

  my (
    $user, $pass,    $private_key, $public_key, $server,
    $port, $timeout, $auth_type,   $is_sudo
  );

  $user        = $option{user};
  $pass        = $option{password};
  $server      = $option{server};
  $port        = $option{port};
  $timeout     = $option{timeout};
  $public_key  = $option{public_key};
  $private_key = $option{private_key};
  $auth_type   = $option{auth_type};
  $is_sudo     = $option{sudo};

  $self->{server}        = $server;
  $self->{is_sudo}       = $is_sudo;
  $self->{__auth_info__} = \%option;

  Rex::Logger::debug("Using Net::SSH2 for connection");
  Rex::Logger::debug( "Using user: " . $user );
  Rex::Logger::debug( Rex::Logger::masq( "Using password: %s", $pass ) )
    if defined $pass;

  $self->{ssh} = Net::SSH2->new;

  my $fail_connect = 0;

CON_SSH:
  $port    ||= Rex::Config->get_port( server => $server )    || 22;
  $timeout ||= Rex::Config->get_timeout( server => $server ) || 3;
  $self->{ssh}->timeout( $timeout * 1000 );

  $server =
    Rex::Config->get_ssh_config_hostname( server => $server ) || $server;

  ( $server, $port ) = Rex::Helper::IP::get_server_and_port( $server, $port );

  Rex::Logger::debug( "Connecting to $server:$port (" . $user . ")" );

  unless ( $self->{ssh}->connect( $server, $port ) ) {
    ++$fail_connect;
    sleep 1;
    goto CON_SSH
      if (
      $fail_connect < Rex::Config->get_max_connect_fails( server => $server ) )
      ; # try connecting 3 times

    Rex::Logger::info( "Can't connect to $server", "warn" );

    $self->{connected} = 0;

    return;
  }

  Rex::Logger::debug( "Current Error-Code: " . $self->{ssh}->error() );
  Rex::Logger::debug("Connected to $server, trying to authenticate.");

  $self->{connected} = 1;

  if ( $auth_type && $auth_type eq "pass" ) {
    Rex::Logger::debug("Using password authentication.");
    $self->{auth_ret} = $self->{ssh}->auth_password( $user, $pass );
    if ( !$self->{auth_ret} ) {

      # try guessing
      $self->{auth_ret} = $self->{ssh}->auth(
        'username' => $user,
        'password' => $pass
      );

    }
  }
  elsif ( $auth_type && $auth_type eq "key" ) {
    Rex::Logger::debug("Using key authentication.");

    croak "No public_key file defined."  if !$public_key;
    croak "No private_key file defined." if !$private_key;

    $self->{auth_ret} =
      $self->{ssh}->auth_publickey( $user, $public_key, $private_key, $pass );
  }
  else {
    Rex::Logger::debug("Trying to guess the authentication method.");
    $self->{auth_ret} = $self->{ssh}->auth(
      'username'   => $user,
      'password'   => $pass,
      'publickey'  => $public_key  || "",
      'privatekey' => $private_key || ""
    );
  }

  $self->{sftp} = $self->{ssh}->sftp;
}

sub reconnect {
  my ($self) = @_;
  Rex::Logger::debug("Reconnecting SSH");

  $self->connect( %{ $self->{__auth_info__} } );
}

sub disconnect {
  my ($self) = @_;
  $self->get_connection_object->disconnect;
}

sub error {
  my ($self) = @_;
  return $self->get_connection_object->error;
}

sub get_connection_object {
  my ($self) = @_;
  return $self->{ssh};
}

sub get_fs_connection_object {
  my ($self) = @_;
  if ( !defined $self->{sftp} ) {
    Rex::Logger::info(
      "It seems that you haven't installed or configured sftp on your server.",
      "warn"
    );
    Rex::Logger::info(
      "Rex needs sftp for file operations, so please install one.", "warn" );
    die("No SFTP server found on remote host.");
  }
  return $self->{sftp};
}

sub is_connected {
  my ($self) = @_;
  return $self->{connected};
}

sub is_authenticated {
  my ($self) = @_;
  return $self->{auth_ret};
}

sub get_connection_type {
  my ($self) = @_;

  my $type = "SSH";

  if ( $self->{is_sudo} && $self->{is_sudo} == 1 ) {
    return "Sudo";
  }

  if ( Rex::is_ssh() && !Rex::is_sudo() ) {
    $type = "SSH";
  }
  elsif ( Rex::is_sudo() ) {
    $type = "Sudo";
  }

  return $type;
}

1;
