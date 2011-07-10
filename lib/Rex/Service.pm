#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service;

use strict;
use warnings;

use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Logger;

sub get {

   my $host = Rex::Hardware::Host->get();

   if($host->{"operatingsystem"} eq "CentOS") {
      $host->{"operatingsystem"} = "Redhat";
   }

   if($host->{"operatingsystem"} eq "Ubuntu") {
      $host->{"operatingsystem"} = "Debian";
   }

   my $class = "Rex::Service::" . $host->{"operatingsystem"};
   eval "use $class";

   if($@) {
   
      Rex::Logger::info("OS not supported");
      exit 1;
   
   }

   return $class->new;

}

1;
