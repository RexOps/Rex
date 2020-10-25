#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Connection::HTTP;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Interface::Connection::Base;

BEGIN {
  LWP::UserAgent->use;
  JSON::MaybeXS->use;
}

use Data::Dumper;

use base qw(Rex::Interface::Connection::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  # activate caching
  Rex::Config->set_use_cache(1);

  return $self;
}

sub error { }

sub connect {
  my ( $self, %option ) = @_;
  my ( $user, $pass, $server, $port, $timeout );

  $user    = $option{user};
  $pass    = $option{password};
  $server  = $option{server};
  $port    = $self->_get_port( $option{port} );
  $timeout = $option{timeout};

  $self->{server} = $server;
  $self->{port}   = $port;

  if ( $server =~ m/([^:]+):(\d+)/ ) {
    $server = $self->{server} = $1;
    $port   = $self->{port}   = $2;
  }

  $self->{__user} = $user;
  $self->{__pass} = $pass;

  if (!Rex::Config->has_user
    && Rex::Config->get_ssh_config_username( server => $server ) )
  {
    $user = Rex::Config->get_ssh_config_username( server => $server );
  }

  $self->ua->credentials( "$server:$port", "Rex::Endpoint::HTTP",
    $user => $pass, );

  my $resp = $self->post("/login");
  if ( $resp->{ok} ) {
    Rex::Logger::info("Connected to $server, trying to authenticate.");
  }
  else {
    Rex::Logger::info( "Can't connect to $server", "warn" );
    $self->{connected} = 0;
    return;
  }

  Rex::Logger::info( "Connecting to $server:$port (" . $user . ")" );

}

sub disconnect               { }
sub get_connection_object    { my ($self) = @_; return $self; }
sub get_fs_connection_object { my ($self) = @_; return $self; }
sub is_connected             { return 1; }
sub is_authenticated         { return 1; }

sub exec {
  my ( $self, $cmd ) = @_;
}

sub ua {
  my ($self) = @_;
  return $self->{ua} if $self->{ua};

  $self->{ua} = LWP::UserAgent->new;
}

sub upload {
  my ( $self, $data ) = @_;

  my $res = $self->ua->post(
    $self->_get_proto . "://"
      . $self->{server} . ":"
      . $self->{port}
      . "/fs/upload",
    Content_Type => "multipart/form-data",
    Content      => $data
  );

  if ( $res->is_success ) {
    return decode_json( $res->decoded_content );
  }
  else {
    die("Error requesting /fs/upload.");
  }
}

sub post {
  my ( $self, $service, $data, $header ) = @_;

  $header ||= {};
  $data   ||= {};

  if ( !ref($data) ) {
    die(
      "Invalid 2nd argument. must be arrayRef or hashRef!\npost(\$service, \$ref)"
    );
  }

  my $res = $self->ua->post(
    $self->_get_proto . "://"
      . $self->{server} . ":"
      . $self->{port}
      . "$service",
    %{$header},
    Content => encode_json($data)
  );

  if ( $res->is_success ) {
    return decode_json( $res->decoded_content );
  }
  else {
    die( "Error requesting $service.\n\nError: " . $res->{_content} );
  }

}

sub get {
  my ( $self, $service ) = @_;

  my $res =
    $self->ua->get( $self->_get_proto . "://"
      . $self->{server} . ":"
      . $self->{port}
      . "$service" );

  if ( $res->is_success ) {
    return decode_json( $res->decoded_content );
  }
  else {
    die("Error requesting $service.");
  }

}

sub get_connection_type { return "HTTP"; }

sub _get_proto {
  return "http";
}

sub _get_port {
  my ( $self, $port ) = @_;
  return $port || 8080;
}

1;
