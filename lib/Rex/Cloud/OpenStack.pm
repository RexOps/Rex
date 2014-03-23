#
# (c) Ferenc Erki <erkiferenc@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Cloud::OpenStack;

use strict;
use warnings;

use Rex::Logger;

use base 'Rex::Cloud::Base';

use HTTP::Request::Common qw(:DEFAULT DELETE);
use JSON::XS;
use LWP::UserAgent;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{_agent} = LWP::UserAgent->new;
  $self->{_agent}->env_proxy;

  return $self;
}

sub set_auth {
  my ( $self, %auth ) = @_;

  $self->{auth} = \%auth;
}

sub _request {
  my ( $self, $method, $url, %params ) = @_;
  my $response;

  Rex::Logger::debug("Sending request to $url");
  Rex::Logger::debug("  $_ => $params{$_}") for keys %params;

  {
    no strict 'refs';
    $response = $self->{_agent}->request( $method->( $url, %params ) );
  }

  if ( $response->is_error ) {
    Rex::Logger::info( 'Response indicates an error', 'warn' );
    Rex::Logger::debug( $response->content );
  }

  return decode_json( $response->content ) if $response->content;
}

sub _authenticate {
  my $self = shift;

  my $auth_data = {
    auth => {
      tenantName => $self->{auth}{tenantName} || '',
      passwordCredentials => {
        username => $self->{auth}{username},
        password => $self->{auth}{password},
      }
    }
  };

  my $content = $self->_request(
    POST         => $self->{__endpoint} . '/tokens',
    content_type => 'application/json',
    content      => encode_json($auth_data),
  );

  $self->{auth}{tokenId} = $content->{access}{token}{id};

  $self->{_agent}->default_header( 'X-Auth-Token' => $self->{auth}{tokenId} );

  $self->{_catalog} = $content->{access}{serviceCatalog};
}

sub get_nova_url {
  my $self = shift;

  $self->_authenticate unless $self->{auth}{tokenId};

  my @nova_services =
    grep { $_->{type} eq 'compute' } @{ $self->{_catalog} };
  return $nova_services[0]{endpoints}[0]{publicURL};
}

sub get_cinder_url {
  my $self = shift;

  $self->_authenticate unless $self->{auth}{tokenId};

  my @cinder_services =
    grep { $_->{type} eq 'volume' } @{ $self->{_catalog} };
  return $cinder_services[0]{endpoints}[0]{publicURL};
}

sub run_instance {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug('Trying to start a new instance with data:');
  Rex::Logger::debug("  $_ => $data{$_}") for keys %data;

  my $request_data = {
    server => {
      flavorRef => $data{plan_id},
      imageRef  => $data{image_id},
      name      => $data{name},
    }
  };

  $self->_request(
    POST         => $nova_url . '/servers',
    content_type => 'application/json',
    content      => encode_json($request_data),
  );
}

sub terminate_instance {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug("Terminating instance $data{instance_id}");

  $self->_request( DELETE => $nova_url . '/servers/' . $data{instance_id} );
}

sub list_instances {
  my $self     = shift;
  my $nova_url = $self->get_nova_url;
  my @instances;

  my $content = $self->_request( GET => $nova_url . '/servers/detail' );

  for my $instance ( @{ $content->{servers} } ) {
    push @instances,
      {
      ip              => $instance->{addresses}{public}[0]{addr},
      id              => $instance->{id},
      architecture    => undef,
      type            => $instance->{flavor}{id},
      dns_name        => undef,
      state           => $instance->{status},
      launch_time     => $instance->{'OS-SRV-USG:launched_at'},
      name            => $instance->{name},
      private_ip      => $instance->{addresses}{private}[0]{addr},
      security_groups => join ',',
      map { $_->{name} } @{ $instance->{security_groups} },
      };
  }

  return @instances;
}

sub list_running_instances {
  my $self = shift;

  return grep { $_->{state} eq 'ACTIVE' } $self->list_instances;
}

sub stop_instance {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug("Suspending instance $data{instance_id}");

  $self->_request(
    POST         => $nova_url . '/servers/' . $data{instance_id} . '/action',
    content_type => 'application/json',
    content      => encode_json( { suspend => 'null' } ),
  );
}

sub start_instance {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug("Resuming instance $data{instance_id}");

  $self->_request(
    POST         => $nova_url . '/servers/' . $data{instance_id} . '/action',
    content_type => 'application/json',
    content      => encode_json( { resume => 'null' } ),
  );
}

sub list_flavors {
  my $self     = shift;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug('Listing flavors');

  $self->_request( GET => $nova_url . '/flavors' );
}

sub list_images {
  my $self     = shift;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug('Listing images');

  $self->_request( GET => $nova_url . '/images' );
}

sub create_volume {
  my ( $self, %data ) = @_;
  my $cinder_url = $self->get_cinder_url;

  Rex::Logger::debug('Creating a new volume');

  my $request_data = {
    volume => {
      size => $data{size} || 1,
      availability_zone => $data{zone},
    }
  };

  $self->_request(
    POST         => $cinder_url . '/volumes',
    content_type => 'application/json',
    content      => encode_json($request_data),
  );
}

1;
