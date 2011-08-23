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

   my $host = Rex::Hardware::Host->get();

   #if(lc($host->{"operatingsystem"}) eq "centos" || lc($host->{"operatingsystem"}) eq "redhat") {
   if(is_redhat()) {
      $host->{"operatingsystem"} = "Redhat";
   }

   my $class = "Rex::Pkg::" . $host->{"operatingsystem"};
   eval "use $class";

   if($@) {
   
      Rex::Logger::info("OS not supported (" . $host->{"operatingsystem"} . ")");
      exit 1;
   
   }

   return $class->new;

}

1;
