#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Cloud - Cloud Management Commands

=head1 DESCRIPTION

With this Module you can manage different Cloud services. Currently it supports Amazon EC2 and Jiffybox.

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
          name     => "test01",
          key      => "my-key",
          volume   => $vol_id,
          zone     => "eu-west-1a",
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
use vars qw(@EXPORT $cloud_service $access_key $secret_access_key $cloud_region);

use Rex::Logger;
use Rex::Config;
use Rex::Cloud;
use Rex::Group::Entry::Server;
    
@EXPORT = qw(cloud_instance cloud_volume 
               cloud_instance_list cloud_volume_list
               cloud_service cloud_auth cloud_region 
               get_cloud_instances_as_group get_cloud_regions get_cloud_availability_zones
               get_cloud_plans
               get_cloud_operating_systems);

Rex::Config->register_set_handler("cloud" => sub {
   my ($name, @options) = @_;
   my $sub_name = "cloud_$name";

   if($name eq "service") {
      cloud_service(@options);
   }

   if($name eq "auth") {
      cloud_auth(@options);
   }

   if($name eq "region") {
      cloud_region(@options);
   }
});

=item cloud_service($cloud_service)

Define which cloud service to use.

=over 4

=item Services

=over 4

=item Amazon

=item Jiffybox

=back

=back


=cut
sub cloud_service {
   ($cloud_service) = @_;

   # set retry counter to a higher value
   if(Rex::Config->get_max_connect_fails() < 5) {
      Rex::Config->set_max_connect_fails(15);
   }
}


=item cloud_auth($access_key, $secret_access_key)

Set the authentication for the cloudservice.

=cut
sub cloud_auth {
   ($access_key, $secret_access_key) = @_;
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
       say "IP    : " . $instance->{"ip"};
       say "ID    : " . $instance->{"id"};
       say "State : " . $instance->{"state"};
    }
 };

=cut

sub cloud_instance_list {

   my $cloud = get_cloud_service($cloud_service);
   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   return $cloud->list_instances();

}

=item cloud_volume_list

Get all volumes of a cloud service.

 task "list-volumes", sub {
    for my $volume (cloud_volume_list()) {
       say "ID       : " . $volume->{"id"};
       say "Zone     : " . $volume->{"zone"};
       say "State    : " . $volume->{"state"};
       say "Attached : " . $volume->{"attached_to"};
    }
 };

=cut

sub cloud_volume_list {
   
   my $cloud = get_cloud_service($cloud_service);
   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   return $cloud->list_volumes();

}

=item get_cloud_instances_as_group

Get a list of all running instances of a cloud service. This can be used for a I<group> definition.

 group fe  => "fe01", "fe02", "fe03";
 group ec2 => get_cloud_instances_as_group();

=cut

sub get_cloud_instances_as_group {
   
   # return funcRef
   return sub {
      my $cloud = get_cloud_service($cloud_service);
      $cloud->set_auth($access_key, $secret_access_key);
      $cloud->set_endpoint($cloud_region);

      my @list = $cloud->list_running_instances();

      my @ret;

      for my $instance (@list) {
         push(@ret, Rex::Group::Entry::Server->new(name => $instance->{"ip"}));
      }

      return @ret;
   };

}

=item cloud_instance($action, $data)

This function controlls all aspects of a cloud instance.

=cut

sub cloud_instance {

   my ($action, $data) = @_;
   my $cloud = get_cloud_service($cloud_service);

   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   if($action eq "list") {
      return $cloud->list_running_instances();
   }

=item create

Create a new instance.

 cloud_instance create => {
       image_id => "ami-xxxxxx",
       key      => "ssh-key",
       name     => "fe-ec2-01",   # name is not necessary
       volume   => "vol-yyyyy",   # volume is not necessary
       zone     => "eu-west-1a",  # zone is not necessary
    };

=cut

   elsif($action eq "create") {
      my %data_hash = (
         image_id => $data->{"image_id"},
         name     => $data->{"name"} || undef,
         key      => $data->{"key"} || undef,
         zone     => $data->{"zone"} || undef,
         volume   => $data->{"volume"} || undef,
         password => $data->{"password"} || undef,
         plan_id  => $data->{"plan_id"} || undef,
         type     => $data->{"type"} || undef,
      );

      if(exists $data->{"metadata"}) {
         $data_hash{"metadata"} = $data->{"metadata"};
      }

      $cloud->run_instance(%data_hash);
   }

=item start

Start an existing instance

 cloud_instance start => "instance-id";

=cut

   elsif($action eq "start") {
      $cloud->start_instance(instance_id => $data);
   }

=item stop

Stop an existing instance

 cloud_instance stop => "instance-id";

=cut

   elsif($action eq "stop") {
      $cloud->stop_instance(instance_id => $data);
   }

=item terminate

Terminate an instance. This will destroy all data and remove the instance.

 cloud_instance terminate => "i-zzzzzzz";

=cut

   elsif($action eq "terminate") {
      $cloud->terminate_instance(instance_id => $data);
   }

}

=item get_cloud_regions

Returns all regions as an array.

=cut

sub get_cloud_regions {

   my $cloud = get_cloud_service($cloud_service);

   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   return $cloud->get_regions;
}

=item cloud_volume($action , $data)

This function controlls all aspects of a cloud volume.

=cut

sub cloud_volume {

   my ($action, $data) = @_;
   my $cloud = get_cloud_service($cloud_service);

   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);


=item create

Create a new volume. Size is in Gigabytes.

 task "create-vol", sub {
    my $vol_id = cloud_volume create => { size => 1, zone => "eu-west-1a", };
 };

=cut

   if($action eq "create") {
      $cloud->create_volume(
                        size => $data->{"size"} || 1,
                        zone => $data->{"zone"} || undef,
                     );
   }

=item detach

Detach a volume from an instance.

 task "detach-vol", sub {
    cloud_volume detach => "vol-xxxxxx";
 };

=cut

   elsif($action eq "detach") {
      my $vol_id;

      if(ref($data)) {
         $vol_id = $data->{"id"};
      }
      else {
         $vol_id = $data;
      }

      $cloud->detach_volume(
         volume_id => $vol_id,
      );
   }

=item delete

Delete a volume. This will destroy all data.

 task "delete-vol", sub {
    cloud_volume delete => "vol-xxxxxx";
 };

=cut

   elsif($action eq "delete") {
      $cloud->delete_volume(volume_id => $data);
   }

   elsif($action eq "list") {
      return $cloud->list_volumes();
   }

}

=item get_cloud_availability_zones

Returns all availability zones of a cloud services. If available.

 task "get-zones", sub {
    print Dumper get_cloud_availability_zones;
 };

=cut

sub get_cloud_availability_zones {

   my $cloud = get_cloud_service($cloud_service);

   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   return $cloud->get_availability_zones();

}

=item get_cloud_plans

Retrieve information of the available cloud plans. If supported.

=cut
sub get_cloud_plans {
   my $cloud = get_cloud_service($cloud_service);

   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   return $cloud->list_plans;
}

=item get_cloud_operating_systems

Retrieve information of the available cloud plans. If supported.

=cut
sub get_cloud_operating_systems {
   my $cloud = get_cloud_service($cloud_service);

   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   return $cloud->list_operating_systems;
}

=back

=cut


1;
