#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware;

use strict;
use warnings;

sub get {
   my($class, @modules) = @_;

   my %hardware_information;

   if("all" eq "\L$modules[0]") {

      @modules = qw(Host Kernel Memory Network Swap);
   
   }

   for my $mod_string (@modules) {

      my $mod = "Rex::Hardware::$mod_string";
      Rex::Logger::debug("Loading Rex::Hardware::$mod_string");
      eval "use Rex::Hardware::$mod_string";

      if($@) {
         Rex::Logger::info("Rex::Hardware::$mod_string not found.");
         Rex::Logger::debug("$@");
         next;
      }

      $hardware_information{$mod_string} = $mod->get();
   }

   return %hardware_information;
}

1;
