#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Network;

use strict;
use warnings;

use Data::Dumper;

use Rex::Commands::Gather;
use Rex::Logger;

sub get {

   my $hw_class = _get_class();

   unless($hw_class) {
      return {};
   }

   return {
 
      networkdevices => $hw_class->get_network_devices(),
      networkconfiguration => $hw_class->get_network_configuration(),

   };

}

sub route {
   return _get_class()->route();
}

sub default_gateway {
   return _get_class()->default_gateway(@_);
}

sub netstat {
   return _get_class()->netstat();
}

sub _get_class {
   my $os_type = Rex::Commands::Gather::get_operating_system();

   $os_type = "Linux"   if Rex::Commands::Gather::is_linux();
   $os_type = "Solaris" if Rex::Commands::Gather::is_solaris();

   my $hw_class = "Rex::Hardware::Network::$os_type";
   eval "use $hw_class;";

   if($@) {
      Rex::Logger::debug("No network information on $os_type");
      return;
   }

   return $hw_class;
}

1;
