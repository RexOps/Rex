#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Connection::OpenSSH;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  use Rex::Require;
  Net::OpenSSH->require;
}

use Rex::Interface::Connection::Base;
use Rex::Helper::IP;
use Data::Dumper;
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

  Rex::Logger::debug("Using Net::OpenSSH for connection");
  Rex::Logger::debug( "Using user: " . $user );
  Rex::Logger::debug( Rex::Logger::masq( "Using password: %s", $pass ) )
    if defined $pass;

  my $proxy_command = Rex::Config->get_proxy_command( server => $server );

  $port    ||= Rex::Config->get_port( server => $server )    || 22;
  $timeout ||= Rex::Config->get_timeout( server => $server ) || 3;

  $server =
    Rex::Config->get_ssh_config_hostname( server => $server ) || $server;

  ( $server, $port ) = Rex::Helper::IP::get_server_and_port( $server, $port );

  Rex::Logger::debug( "Connecting to $server:$port (" . $user . ")" );

  my %ssh_opts = Rex::Config->get_openssh_opt();
  Rex::Logger::debug("get_openssh_opt()");
  Rex::Logger::debug( Dumper( \%ssh_opts ) );

  $ssh_opts{LogLevel} ||= "QUIET";
  $ssh_opts{ConnectTimeout} = $timeout;

  my %net_openssh_constructor_options = (
    exists $ssh_opts{initialize_options}
    ? %{ $ssh_opts{initialize_options} }
    : ()
  );

  delete $ssh_opts{initialize_options}
    if ( exists $ssh_opts{initialize_options} );

  my @ssh_opts_line;

  for my $key ( keys %ssh_opts ) {
    push @ssh_opts_line, "-o" => $key . "=" . $ssh_opts{$key};
  }

  my @connection_props = ( "" . $server ); # stringify server object, so that a dumper don't print out passwords.
  push @connection_props, ( user => $user, port => $port );

  if (@ssh_opts_line) {
    if ( !$net_openssh_constructor_options{external_master} ) {
      push @connection_props, master_opts => \@ssh_opts_line;
    }

    push @connection_props, default_ssh_opts => \@ssh_opts_line;
  }

  push @connection_props, proxy_command => $proxy_command if $proxy_command;

  my @auth_types_to_try;
  if ( $auth_type && $auth_type eq "pass" ) {
    Rex::Logger::debug(
      Rex::Logger::masq(
        "OpenSSH: pass_auth: $server:$port - $user - %s", $pass
      )
    );
    push @auth_types_to_try, "pass";
  }
  elsif ( $auth_type && $auth_type eq "krb5" ) {
    Rex::Logger::debug("OpenSSH: krb5_auth: $server:$port - $user");
    push @auth_types_to_try, "krb5";

    # do nothing here
  }
  else { # for key auth, and others
    Rex::Logger::debug(
      "OpenSSH: key_auth or not defined: $server:$port - $user");
    push @auth_types_to_try, "key", "pass";
  }

  Rex::Logger::debug("OpenSSH options: ");
  Rex::Logger::debug( Dumper( \@connection_props ) );
  Rex::Logger::debug("OpenSSH constructor options: ");
  Rex::Logger::debug( Dumper( \%net_openssh_constructor_options ) );
  Rex::Logger::debug("Trying following auth types:");
  Rex::Logger::debug( Dumper( \@auth_types_to_try ) );

  my $fail_connect = 0;
CONNECT_TRY:
  while (
    $fail_connect < Rex::Config->get_max_connect_fails( server => $server ) )
  {

    for my $_try_auth_type (@auth_types_to_try) {

      my @_internal_con_props = @connection_props;

      if ( $_try_auth_type eq "pass" ) {
        push @_internal_con_props, password => $pass;
      }
      elsif ( $_try_auth_type eq "key" ) {
        push @_internal_con_props, key_path => $private_key;
        if ($pass) {
          push @_internal_con_props, passphrase => $pass;
        }
      }

      $self->{ssh} =
        Net::OpenSSH->new( @_internal_con_props,
        %net_openssh_constructor_options );

      if ( $self->{ssh} && !$self->{ssh}->error ) {
        last CONNECT_TRY;
      }
    }

    $fail_connect++;
  }

  if ( !$self->{ssh} ) {
    Rex::Logger::info( "Can't connect to $server", "warn" );
    $self->{connected} = 0;
    return;
  }

  if ( $self->{ssh} && $self->{ssh}->error ) {
    Rex::Logger::info(
      "Can't authenticate against $server (" . $self->{ssh}->error() . ")",
      "warn" );
    $self->{connected} = 1;

    return;
  }

  Rex::Logger::debug( "Current Error-Code: " . $self->{ssh}->error() );
  Rex::Logger::debug("Connected and authenticated to $server.");

  $self->{connected} = 1;
  $self->{auth_ret}  = 1;

  eval { $self->{sftp} = $self->{ssh}->sftp; };
}

sub reconnect {
  my ($self) = @_;
  Rex::Logger::debug("Reconnecting SSH");

  $self->connect( %{ $self->{__auth_info__} } );
}

sub disconnect {
  my ($self) = @_;
  undef $self->{ssh};
  return 1;
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

  my $type = "OpenSSH";

  if ( $self->{is_sudo} && $self->{is_sudo} == 1 ) {
    return "Sudo";
  }

  if ( Rex::is_ssh() && !Rex::is_sudo() ) {
    $type = "OpenSSH";
  }
  elsif ( Rex::is_sudo() ) {
    $type = "Sudo";
  }

  return $type;
}

1;
