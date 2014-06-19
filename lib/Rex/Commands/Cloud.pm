#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Cloud - Cloud Management Commands

=head1 DESCRIPTION

With this Module you can manage different Cloud services. Currently it supports Amazon EC2, Jiffybox and OpenStack.

Version <= 1.0: All these functions will not be reported.

=head1 SYNOPSIS

 use Rex::Commands::Cloud;

 cloud_service "Amazon";
 cloud_auth "your-access-key", "your-private-access-key";
 cloud_region "ec2.eu-west-1.amazonaws.com";

 task "list", sub {
   print Dumper cloud_instance_list;
   print Dumper cloud_volume_list;
 };

 task "create", sub {
   my $vol_id = cloud_volume create => { size => 1, zone => "eu-west-1a", };

   cloud_instance create => {
       image_id => "ami-xxxxxxx",
       name    => "test01",
       key    => "my-key",
       volume  => $vol_id,
       zone    => "eu-west-1a",
     };
 };

 task "destroy", sub {
   cloud_volume detach => "vol-xxxxxxx";
   cloud_volume delete => "vol-xxxxxxx";

   cloud_instance terminate => "i-xxxxxxx";
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Cloud;

use strict;
use warnings;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT $cloud_service $cloud_region @cloud_auth);

use Rex::Logger;
use Rex::Config;
use Rex::Cloud;
use Rex::Group::Entry::Server;

@EXPORT = qw(cloud_instance cloud_volume cloud_network
  cloud_instance_list cloud_volume_list cloud_network_list
  cloud_service cloud_auth cloud_region
  get_cloud_instances_as_group get_cloud_regions get_cloud_availability_zones
  get_cloud_plans
  get_cloud_operating_systems
  cloud_image_list
  cloud_object);

Rex::Config->register_set_handler(
  "cloud" => sub {
    my ( $name, @options ) = @_;
    my $sub_name = "cloud_$name";

    if ( $name eq "service" ) {
      cloud_service(@options);
    }

    if ( $name eq "auth" ) {
      cloud_auth(@options);
    }

    if ( $name eq "region" ) {
      cloud_region(@options);
    }
  }
);

=item cloud_service($cloud_service)

Define which cloud service to use.

=over 4

=item Services

=over 4

=item Amazon

=item Jiffybox

=item OpenStack

=back

=back


=cut

sub cloud_service {
  ($cloud_service) = @_;

  # set retry counter to a higher value
  if ( Rex::Config->get_max_connect_fails() < 5 ) {
    Rex::Config->set_max_connect_fails(15);
  }
}

=item cloud_auth($param1, $param2, ...)

Set the authentication for the cloudservice.

For example for Amazon it is:

 cloud_auth($access_key, $secret_access_key);

For JiffyBox:

 cloud_auth($auth_key);

For OpenStack:

 cloud_auth(
  tenant_name => 'tenant',
  username    => 'user',
  password    => 'password',
 );

=cut

sub cloud_auth {
  @cloud_auth = @_;
}

=item cloud_region($region)

Set the cloud region.

=cut

sub cloud_region {
  ($cloud_region) = @_;
}

=item cloud_instance_list

Get all instances of a cloud service.

 task "list", sub {
   for my $instance (cloud_instance_list()) {
     say "Arch  : " . $instance->{"architecture"};
     say "IP   : " . $instance->{"ip"};
     say "ID   : " . $instance->{"id"};
     say "State : " . $instance->{"state"};
   }
 };

=cut

sub cloud_instance_list {
  return cloud_object()->list_instances();
}

=item cloud_volume_list

Get all volumes of a cloud service.

 task "list-volumes", sub {
   for my $volume (cloud_volume_list()) {
     say "ID     : " . $volume->{"id"};
     say "Zone    : " . $volume->{"zone"};
     say "State   : " . $volume->{"state"};
     say "Attached : " . $volume->{"attached_to"};
   }
 };

=cut

sub cloud_volume_list {
  return cloud_object()->list_volumes();
}

=item cloud_network_list

Get all networks of a cloud service.

 task "network-list", sub {
   for my $network (cloud_network_list()) {
     say "network  : " . $network->{network};
     say "name    : " . $network->{name};
     say "id     : " . $network->{id};
   }
 };

=cut

sub cloud_network_list {
  return cloud_object()->list_networks();
}

=item cloud_image_list

Get a list of all available cloud images.

=cut

sub cloud_image_list {
  return cloud_object()->list_images();
}

=item get_cloud_instances_as_group

Get a list of all running instances of a cloud service. This can be used for a I<group> definition.

 group fe  => "fe01", "fe02", "fe03";
 group ec2 => get_cloud_instances_as_group();

=cut

sub get_cloud_instances_as_group {

  # return funcRef
  return sub {
    my @list = cloud_object()->list_running_instances();

    my @ret;

    for my $instance (@list) {
      push( @ret, Rex::Group::Entry::Server->new( name => $instance->{"ip"} ) );
    }

    return @ret;
  };

}

=item cloud_instance($action, $data)

This function controlls all aspects of a cloud instance.

=cut

sub cloud_instance {

  my ( $action, $data ) = @_;
  my $cloud = cloud_object();

  if ( $action eq "list" ) {
    return $cloud->list_running_instances();
  }

=item create

Create a new instance.

 cloud_instance create => {
     image_id => "ami-xxxxxx",
     key    => "ssh-key",
     name    => "fe-ec2-01",  # name is not necessary
     volume  => "vol-yyyyy",  # volume is not necessary
     zone    => "eu-west-1a",  # zone is not necessary
   };

=cut

  elsif ( $action eq "create" ) {
    my %data_hash = (

      # image_id => $data->{"image_id"},
      # name    => $data->{"name"} || undef,
      # key    => $data->{"key"} || undef,
      # zone    => $data->{"zone"} || undef,
      # volume  => $data->{"volume"} || undef,
      # password => $data->{"password"} || undef,
      # plan_id  => $data->{"plan_id"} || undef,
      # type    => $data->{"type"} || undef,
      # security_group => $data->{"security_group"} || undef,
      %{$data},
    );

    $cloud->run_instance(%data_hash);
  }

=item start

Start an existing instance

 cloud_instance start => "instance-id";

=cut

  elsif ( $action eq "start" ) {
    $cloud->start_instance( instance_id => $data );
  }

=item stop

Stop an existing instance

 cloud_instance stop => "instance-id";

=cut

  elsif ( $action eq "stop" ) {
    $cloud->stop_instance( instance_id => $data );
  }

=item terminate

Terminate an instance. This will destroy all data and remove the instance.

 cloud_instance terminate => "i-zzzzzzz";

=cut

  elsif ( $action eq "terminate" ) {
    $cloud->terminate_instance( instance_id => $data );
  }

}

=item get_cloud_regions

Returns all regions as an array.

=cut

sub get_cloud_regions {
  return cloud_object()->get_regions;
}

=item cloud_volume($action , $data)

This function controlls all aspects of a cloud volume.

=cut

sub cloud_volume {

  my ( $action, @_data ) = @_;
  my $data;
  if ( @_data == 1 ) {
    if ( ref $_data[0] ) {
      $data = $_data[0];
    }
    else {
      $data = { id => $_data[0] };
    }
  }
  else {
    $data = { "id", @_data };
  }

  my $cloud = cloud_object();

=item create

Create a new volume. Size is in Gigabytes.

 task "create-vol", sub {
   my $vol_id = cloud_volume create => { size => 1, zone => "eu-west-1a", };
 };

=cut

  if ( $action eq "create" ) {
    $cloud->create_volume(
      size => $data->{"size"} || 1,
      %{$data},
    );
  }

=item attach

Attach a volume to an instance.

 task "attach-vol", sub {
   cloud_volume attach => "vol-xxxxxx", to => "server-id";
 };

=cut

  elsif ( $action eq "attach" ) {
    my $vol_id = $data->{id};
    my $srv_id = $data->{to};

    $cloud->attach_volume(
      volume_id   => $vol_id,
      server_id   => $srv_id,
      device_name => $data->{device}
    );
  }

=item detach

Detach a volume from an instance.

 task "detach-vol", sub {
   cloud_volume detach => "vol-xxxxxx", from => "server-id";
 };

=cut

  elsif ( $action eq "detach" ) {
    my $vol_id = $data->{id};
    my $srv_id = $data->{from};

    $cloud->detach_volume(
      volume_id => $vol_id,
      server_id => $srv_id,
      attach_id => $data->{attach_id}
    );
  }

=item delete

Delete a volume. This will destroy all data.

 task "delete-vol", sub {
   cloud_volume delete => "vol-xxxxxx";
 };

=cut

  elsif ( $action eq "delete" ) {
    $cloud->delete_volume( volume_id => $data->{id} );
  }

  elsif ( $action eq "list" ) {
    return $cloud->list_volumes();
  }

}

=item cloud_network

=cut

sub cloud_network {

  my ( $action, $data ) = @_;
  my $cloud = cloud_object();

=item create

Create a new network.

 task "create-net", sub {
   my $net_id = cloud_network create => { cidr => '192.168.0.0/24', name => "mynetwork", };
 };

=cut

  if ( $action eq "create" ) {
    $cloud->create_network( %{$data} );
  }

=item delete

Delete a network.

 task "delete-net", sub {
   cloud_network delete => '18a4ccf8-f14a-a10d-1af4-4ac7fee08a81';
 };

=cut

  elsif ( $action eq "delete" ) {
    $cloud->delete_network($data);
  }
}

=item get_cloud_availability_zones

Returns all availability zones of a cloud services. If available.

 task "get-zones", sub {
   print Dumper get_cloud_availability_zones;
 };

=cut

sub get_cloud_availability_zones {
  return cloud_object()->get_availability_zones();
}

=item get_cloud_plans

Retrieve information of the available cloud plans. If supported.

=cut

sub get_cloud_plans {
  return cloud_object()->list_plans;
}

=item get_cloud_operating_systems

Retrieve information of the available cloud plans. If supported.

=cut

sub get_cloud_operating_systems {
  return cloud_object()->list_operating_systems;
}

=item cloud_object

Returns the cloud object itself.

=cut

sub cloud_object {
  my $cloud = get_cloud_service($cloud_service);

  $cloud->set_auth(@cloud_auth);
  $cloud->set_endpoint($cloud_region);

  return $cloud;
}

=back

=cut

1;
