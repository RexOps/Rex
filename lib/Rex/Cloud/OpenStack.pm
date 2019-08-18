#
# (c) Ferenc Erki <erkiferenc@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Cloud::OpenStack;

use strict;
use warnings;

# VERSION

use Rex::Logger;

use base 'Rex::Cloud::Base';

BEGIN {
  use Rex::Require;
  JSON::MaybeXS->use;
  HTTP::Request::Common->use(qw(:DEFAULT DELETE));
  LWP::UserAgent->use;
}
use Data::Dumper;
use Carp;
use MIME::Base64 qw(decode_base64);
use Digest::MD5 qw(md5_hex);
use File::Basename;

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

  Rex::Logger::debug( Dumper($response) );

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
      tenantName          => $self->{auth}{tenant_name} || '',
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
      key_name  => $data{key},
    }
  };

  my $content = $self->_request(
    POST         => $nova_url . '/servers',
    content_type => 'application/json',
    content      => encode_json($request_data),
  );

  my $id = $content->{server}{id};
  my $info;

  until ( ($info) = grep { $_->{id} eq $id } $self->list_running_instances ) {
    Rex::Logger::debug('Waiting for instance to be created...');
    sleep 1;
  }

  if ( exists $data{volume} ) {
    $self->attach_volume(
      instance_id => $id,
      volume_id   => $data{volume},
    );
  }

  if ( exists $data{floating_ip} ) {
    $self->associate_floating_ip(
      instance_id => $id,
      floating_ip => $data{floating_ip},
    );

    ($info) = grep { $_->{id} eq $id } $self->list_running_instances;
  }

  return $info;
}

sub terminate_instance {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug("Terminating instance $data{instance_id}");

  $self->_request( DELETE => $nova_url . '/servers/' . $data{instance_id} );

  until ( !grep { $_->{id} eq $data{instance_id} }
      $self->list_running_instances )
  {
    Rex::Logger::debug('Waiting for instance to be deleted...');
    sleep 1;
  }
}

sub list_instances {
  my $self    = shift;
  my %options = @_;

  $options{private_network} ||= "private";
  $options{public_network}  ||= "public";
  $options{public_ip_type}  ||= "floating";
  $options{private_ip_type} ||= "fixed";

  my $nova_url = $self->get_nova_url;
  my @instances;

  my $content = $self->_request( GET => $nova_url . '/servers/detail' );

  for my $instance ( @{ $content->{servers} } ) {
    my %networks;
    for my $net ( keys %{ $instance->{addresses} } ) {
      for my $ip_conf ( @{ $instance->{addresses}->{$net} } ) {
        push @{ $networks{$net} },
          {
          mac  => $ip_conf->{'OS-EXT-IPS-MAC:mac_addr'},
          ip   => $ip_conf->{addr},
          type => $ip_conf->{'OS-EXT-IPS:type'},
          };
      }
    }

    push @instances, {
      ip => (
        [
          map {
                $_->{"OS-EXT-IPS:type"} eq $options{public_ip_type}
              ? $_->{'addr'}
              : ()
          } @{ $instance->{addresses}{ $options{public_network} } }
        ]->[0]
          || undef
      ),
      id           => $instance->{id},
      architecture => undef,
      type         => $instance->{flavor}{id},
      dns_name     => undef,
      state   => ( $instance->{status} eq 'ACTIVE' ? 'running' : 'stopped' ),
      __state => $instance->{status},
      launch_time => $instance->{'OS-SRV-USG:launched_at'},
      name        => $instance->{name},
      private_ip  => (
        [
          map {
                $_->{"OS-EXT-IPS:type"} eq $options{private_ip_type}
              ? $_->{'addr'}
              : ()
          } @{ $instance->{addresses}{ $options{private_network} } }
        ]->[0]
          || undef
      ),
      security_groups =>
        ( join ',', map { $_->{name} } @{ $instance->{security_groups} } ),
      networks => \%networks,
    };
  }

  return @instances;
}

sub list_running_instances {
  my $self = shift;

  return grep { $_->{state} eq 'running' } $self->list_instances;
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

  while ( grep { $_->{id} eq $data{instance_id} }
    $self->list_running_instances )
  {
    Rex::Logger::debug('Waiting for instance to be stopped...');
    sleep 5;
  }
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

  until ( grep { $_->{id} eq $data{instance_id} }
      $self->list_running_instances )
  {
    Rex::Logger::debug('Waiting for instance to be started...');
    sleep 5;
  }
}

sub list_flavors {
  my $self     = shift;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug('Listing flavors');

  my $flavors = $self->_request( GET => $nova_url . '/flavors' );
  confess "Error getting cloud flavors." if ( !exists $flavors->{flavors} );
  return @{ $flavors->{flavors} };
}

sub list_plans { return shift->list_flavors; }

sub list_images {
  my $self     = shift;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug('Listing images');

  my $images = $self->_request( GET => $nova_url . '/images' );
  confess "Error getting cloud images." if ( !exists $images->{images} );
  return @{ $images->{images} };
}

sub create_volume {
  my ( $self, %data ) = @_;
  my $cinder_url = $self->get_cinder_url;

  Rex::Logger::debug('Creating a new volume');

  my $request_data = {
    volume => {
      size              => $data{size} || 1,
      availability_zone => $data{zone},
    }
  };

  my $content = $self->_request(
    POST         => $cinder_url . '/volumes',
    content_type => 'application/json',
    content      => encode_json($request_data),
  );

  my $id = $content->{volume}{id};

  until ( grep { $_->{id} eq $id and $_->{status} eq 'available' }
      $self->list_volumes )
  {
    Rex::Logger::debug('Waiting for volume to become available...');
    sleep 1;
  }

  return $id;
}

sub delete_volume {
  my ( $self, %data ) = @_;
  my $cinder_url = $self->get_cinder_url;

  Rex::Logger::debug('Trying to delete a volume');

  $self->_request( DELETE => $cinder_url . '/volumes/' . $data{volume_id} );

  until ( !grep { $_->{id} eq $data{volume_id} } $self->list_volumes ) {
    Rex::Logger::debug('Waiting for volume to be deleted...');
    sleep 1;
  }

}

sub list_volumes {
  my $self       = shift;
  my $cinder_url = $self->get_cinder_url;
  my @volumes;

  my $content = $self->_request( GET => $cinder_url . '/volumes' );

  for my $volume ( @{ $content->{volumes} } ) {
    push @volumes,
      {
      id          => $volume->{id},
      status      => $volume->{status},
      zone        => $volume->{availability_zone},
      size        => $volume->{size},
      attached_to => join ',',
      map { $_->{server_id} } @{ $volume->{attachments} },
      };
  }

  return @volumes;
}

sub attach_volume {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug('Trying to attach a new volume');

  my $request_data = {
    volumeAttachment => {
      volumeId => $data{volume_id},
      name     => $data{name},
    }
  };

  $self->_request(
    POST => $nova_url
      . '/servers/'
      . $data{instance_id}
      . '/os-volume_attachments',
    content_type => 'application/json',
    content      => encode_json($request_data),
  );
}

sub detach_volume {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  Rex::Logger::debug('Trying to detach a volume');

  $self->_request( DELETE => $nova_url
      . '/servers/'
      . $data{instance_id}
      . '/os-volume_attachments/'
      . $data{volume_id} );
}

sub get_floating_ip {
  my $self     = shift;
  my $nova_url = $self->get_nova_url;

  # look for available floating IP
  my $floating_ips = $self->_request( GET => $nova_url . '/os-floating-ips' );

  for my $floating_ip ( @{ $floating_ips->{floating_ips} } ) {
    return $floating_ip->{ip} if ( !$floating_ip->{instance_id} );
  }
  confess "No floating IP available.";
}

sub associate_floating_ip {
  my ( $self, %data ) = @_;
  my $nova_url = $self->get_nova_url;

  # associate available floating IP to instance id
  my $request_data = {
    addFloatingIp => {
      address => $data{floating_ip}
    }
  };

  Rex::Logger::debug('Associating floating IP to instance');

  my $content = $self->_request(
    POST         => $nova_url . '/servers/' . $data{instance_id} . '/action',
    content_type => 'application/json',
    content      => encode_json($request_data),
  );
}

sub list_keys {
  my $self     = shift;
  my $nova_url = $self->get_nova_url;

  my $content = $self->_request( GET => $nova_url . '/os-keypairs' );

  # remove ':' from fingerprint string
  foreach ( @{ $content->{keypairs} } ) {
    $_->{keypair}->{fingerprint} =~ s/://g;
  }
  return @{ $content->{keypairs} };
}

sub upload_key {
  my ($self) = shift;
  my $nova_url = $self->get_nova_url;

  my $public_key = glob( Rex::Config->get_public_key );
  my ( $public_key_name, undef, undef ) = fileparse( $public_key, qr/\.[^.]*/ );

  my ( $type, $key, $comment );

  # read public key
  my $fh;
  unless ( open( $fh, "<", glob($public_key) ) ) {
    Rex::Logger::debug("Cannot read $public_key");
    return;
  }

  { local $/ = undef; ( $type, $key, $comment ) = split( /\s+/, <$fh> ); }
  close $fh;

  # calculate key fingerprint so we can compare them
  my $fingerprint = md5_hex( decode_base64($key) );
  Rex::Logger::debug("Public key fingerprint is $fingerprint");

  # upoad only new key
  my $online_key = pop @{
    [
      map { $_->{keypair}->{fingerprint} eq $fingerprint ? $_ : () }
        $self->list_keys()
    ]
  };
  if ($online_key) {
    Rex::Logger::debug("Public key already uploaded");
    return $online_key->{keypair}->{name};
  }

  my $request_data = {
    keypair => {
      public_key => "$type $key",
      name       => $public_key_name,
    }
  };

  Rex::Logger::info('Uploading public key');
  $self->_request(
    POST         => $nova_url . '/os-keypairs',
    content_type => 'application/json',
    content      => encode_json($request_data),
  );

  return $public_key_name;
}

1;
