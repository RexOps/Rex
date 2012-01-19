#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::System;
   
use strict;
use warnings;

use Rex::Config;
use Rex::Commands::Run;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Logger;

sub get {

   my $host = Rex::Hardware::Host->get();

   if(is_redhat()) {
      $host->{"operatingsystem"} = "Redhat";
   }

   my $class = "Rex::System::" . $host->{"operatingsystem"};

   Rex::Logger::debug("system using class: $class");
   eval "use $class";

   if($@) {
      Rex::Logger::info("OS (" . $host->{"operatingsystem"} . ") not supported");
      exit 1;
   }

   return $class->new;
}

1;
