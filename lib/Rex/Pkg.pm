#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg;

use strict;
use warnings;

use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Logger;

use Data::Dumper;

sub get {

   my ($self, $provider) = @_;

   my $host = Rex::Hardware::Host->get();

   #if(lc($host->{"operatingsystem"}) eq "centos" || lc($host->{"operatingsystem"}) eq "redhat") {
   if(is_redhat()) {
      $host->{"operatingsystem"} = "Redhat";
   }

   my $class = "Rex::Pkg::" . $host->{"operatingsystem"};

   if($provider) {
      $class .= "::$provider";
   }

   eval "use $class";

   if($@) {
   
      if($provider) {
         Rex::Logger::info("Provider not supported (" . $provider . ")");
      }
      else {
         Rex::Logger::info("OS not supported (" . $host->{"operatingsystem"} . ")");
      }
      die("OS/Provider not supported");
   
   }

   return $class->new;

}

1;
