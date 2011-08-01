#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Commands::Cloud;
   
use strict;
use warnings;
   
require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT $cloud_service $access_key $secret_access_key $cloud_region);

use Rex::Logger;
use Rex::Config;
use Rex::Cloud;
    
@EXPORT = qw(cloud cloud_service cloud_auth cloud_region cloud_list get_cloud_instances_as_group);

sub cloud_service {
   ($cloud_service) = @_;

   # set retry counter to a higher value
   if(Rex::Config->get_max_connect_fails() < 5) {
      Rex::Config->set_max_connect_fails(15);
   }
}

sub cloud_auth {
   ($access_key, $secret_access_key) = @_;
}

sub cloud_region {
   ($cloud_region) = @_;
}

sub cloud_list {

   my $cloud = get_cloud_service($cloud_service);
   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   return $cloud->list_running_instances();

}

sub get_cloud_instances_as_group {
   
   # return funcRef
   return sub {
      my @list = cloud_list;

      my @ret;

      for my $instance (@list) {
         if($instance->{"state"} eq "running") {
            push(@ret, $instance->{"ip"});
         }
      }

      return @ret;
   };

}



sub cloud {

   my ($action, $data) = @_;
   my $cloud = get_cloud_service($cloud_service);

   $cloud->set_auth($access_key, $secret_access_key);
   $cloud->set_endpoint($cloud_region);

   if($action eq "list") {
      return $cloud->list_running_instances();
   }

   elsif($action eq "create") {
      $cloud->run_instance(
         image_id => $data->{"image_id"},
         name     => $data->{"name"} || undef,
         key      => $data->{"key"} || undef,
      );
   }

   elsif($action eq "terminate") {
      $cloud->terminate_instance($data);
   }

}

1;
