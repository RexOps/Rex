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
    
@EXPORT = qw(cloud cloud_service cloud_auth cloud_region cloud_list);

sub cloud_service {
   ($cloud_service) = @_;
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
      );
   }

   elsif($action eq "terminate") {
      $cloud->terminate_instance($data);
   }

}

1;
