#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Cache::RexIO;

use strict;
use warnings;
use Carp;

use Rex::Interface::Cache::Base;
use base qw(Rex::Interface::Cache::Base);
use Data::Dumper;
use Mojo::UserAgent;

require Rex::Commands;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{__rexio__} = {
    server   => Rex::Commands::get("rexio_server"),
    user     => Rex::Config->get("rexio_user"),
    password => Rex::Config->get("rexio_password"),
  };

  confess "No Rex.IO server given." if !$self->{__rexio__}->{server};
  confess "No Rex.IO user given."   if !$self->{__rexio__}->{user};
  confess "No Rex.IO password given."
    if !$self->{__rexio__}->{password};

  return $self;
}

sub save {
  my ($self) = @_;
  Rex::Logger::info("saving cache to rex.io");

  my $res =
    $self->_ua->get( $self->rexio("url")
      . "/1.0/hardware/hardware/"
      . Rex::Commands::connection->server )->res->json;

  if ( $res && $res->{ok} == Mojo::JSON->true ) {
    Rex::Logger::info("System already registered in Rex.IO");
    return;
  }

  # first get the os id
  my $ref = $self->_ua->get( $self->rexio("url") . "/1.0/os/os" )->res->json;
  my $os_id;

  if ( $ref->{ok} == Mojo::JSON->true ) {
    my @os = @{ $ref->{data} };

    my ($wanted_os) = grep {
      $_->{name} eq $self->{__data__}->{"hardware.host"}->{operating_system}
        && $_->{version} eq
        $self->{__data__}->{"hardware.host"}->{operating_system_release}
    } @os;

    if ( !$wanted_os ) {

      # we need to create a new os
      my $new_os = $self->_ua->post(
        $self->rexio("url") . "/1.0/os/os",
        json => {
          version =>
            $self->{__data__}->{"hardware.host"}->{operating_system_release},
          name   => $self->{__data__}->{"hardware.host"}->{operating_system},
          kernel => $self->{__data__}->{"hardware.kernel"}->{kernel},
        }
      )->res->json;

      if ( $new_os->{ok} == Mojo::JSON->true ) {
        $os_id = $new_os->{data}->{id};
      }
      else {
        confess "Error creating new OS in Rex.IO.";
      }
    }
    else {
      # got os, so get the id
      $os_id = $wanted_os->{id};
    }

  }
  else {
    # error getting all os's from rexio
    confess "Error listing available operating systems from Rex.IO.";
  }

  Rex::Logger::info("Got os id: $os_id");

  my $new_hw = $self->_ua->post(
    $self->rexio("url") . "/1.0/hardware/hardware",
    json => {
      name              => $self->{__data__}->{"hardware.host"}->{hostname},
      os_id             => $os_id,
      server_group_id   => 1,
      permission_set_id => 1,
      kernelrelease => $self->{__data__}->{"hardware.kernel"}->{kernelrelease},
      kernelversion => $self->{__data__}->{"hardware.kernel"}->{kernelversion},
      network_adapter => [
        {
          dev => 'eth0',
          broadcast =>
            $self->{__data__}->{"hardware.network"}->{networkconfiguration}
            ->{eth0}->{broadcast},
          ip => $self->{__data__}->{"hardware.network"}->{networkconfiguration}
            ->{eth0}->{ip},
          mac => $self->{__data__}->{"hardware.network"}->{networkconfiguration}
            ->{eth0}->{mac},
          netmask =>
            $self->{__data__}->{"hardware.network"}->{networkconfiguration}
            ->{eth0}->{netmask},
        },
      ],
    }
  )->res->json;

  if ( $new_hw->{ok} == Mojo::JSON->true ) {
  }
  else {
    confess "Error creating new hardware in Rex.IO.";
  }
}

sub load {
  my ($self) = @_;
  Rex::Logger::info("getting cache from rex.io");
  my $res =
    $self->_ua->get( $self->rexio("url")
      . "/1.0/hardware/hardware/"
      . Rex::Commands::connection->server )->res->json;

  if ( $res && $res->{ok} == Mojo::JSON->true ) {
    my ( $hostname, $domain ) = split /\./, $res->{data}->{name}, 2;

    my $networkconfiguration;

    map {
      $networkconfiguration->{ $_->{dev} } = $_;
      delete $networkconfiguration->{dev};
    } @{ $res->{data}->{network_adapters} };

    my $networkdevices =
      [ map { $_ = $_->{dev} } @{ $res->{data}->{network_adapters} } ];

    $self->{__data__}->{"hardware.host"} = {
      domain                   => $domain,
      hostname                 => $hostname,
      kernelname               => $res->{data}->{os}->{kernel},
      operating_system         => $res->{data}->{os}->{name},
      operatingsystem          => $res->{data}->{os}->{name},
      operating_system_release => $res->{data}->{os}->{version},
      operatingsystemrelease   => $res->{data}->{os}->{version},

    };

    $self->{__data__}->{"hardware.kernel"} = {
      kernel        => $res->{data}->{os}->{kernel},
      kernelversion => $res->{data}->{kernelversion},
      kernelrelease => $res->{data}->{kernelrelease},
    };

    $self->{__data__}->{"hardware.network"} = {
      networkconfiguration => $networkconfiguration,
      networkdevices       => $networkdevices,
    };

    return;
  }

  return undef;
}

sub rexio {
  my ( $self, $key ) = @_;
  if ( $key eq "url" ) {
    my ( $proto, $server, $port, $path ) =
      (
      $self->{__rexio__}->{server} =~ m/^(http|https):\/\/([^:]+):(\d+)(.*)$/ );
    $path =~ s/\/$//;    # remove trailing slash
    return
      "$proto://$self->{__rexio__}->{user}:$self->{__rexio__}->{password}\@$server:$port$path";
  }

  return $self->{__rexio__}->{$key};
}

sub _ua {
  my ($self) = @_;
  return Mojo::UserAgent->new;
}

1;
