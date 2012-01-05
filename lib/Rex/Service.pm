#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service;

use strict;
use warnings;

use Rex::Config;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Logger;

sub get {

   my $host = Rex::Hardware::Host->get();

   if(is_redhat()) {
      $host->{"operatingsystem"} = "Redhat";
   }

   my $class = "Rex::Service::" . $host->{"operatingsystem"};

   if(is_redhat() && operating_system_version() >= 16) {
      $class = "Rex::Service::Redhat::systemd";
   }

   if(is_suse() && operating_system_version() >= 121) {
      $class = "Rex::Service::SuSE::systemd";
   }

   my $provider_for = Rex::Config->get("service_provider") || {};
   my $provider;

   if(exists $provider_for->{$host->{"operatingsystem"}}) {
      $provider = $provider_for->{$host->{"operatingsystem"}};
      $class .= "::\L$provider";
   }

   Rex::Logger::debug("service using class: $class");
   eval "use $class";

   if($@) {
   
      Rex::Logger::info("OS (" . $host->{"operatingsystem"} . ") not supported");
      exit 1;
   
   }

   return $class->new;

}

1;
