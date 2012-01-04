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

   my $provider_for = Rex::Config->get("service_provider") || {};
   my $provider;

   if(exists $provider_for->{$host->{"operatingsystem"}}) {
      $provider = $provider_for->{$host->{"operatingsystem"}};
      $class .= "::\L$provider";
   }

   eval "use $class";

   if($@) {
   
      Rex::Logger::info("OS not supported");
      exit 1;
   
   }

   return $class->new;

}

1;
