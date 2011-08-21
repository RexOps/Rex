#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::User;

use strict;
use warnings;

use Rex::Commands::Gather;
use Rex::Logger;

sub get {

   my $user_o = "Linux";

   my $class = "Rex::User::" . $user_o;
   eval "use $class";

   if($@) {
   
      Rex::Logger::info("OS not supported");
      exit 1;
   
   }

   return $class->new;

}

1;
