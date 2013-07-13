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
   if(is_freebsd) {
      $user_o = "FreeBSD";
   }
   elsif(is_netbsd) {
      $user_o = "NetBSD";
   }
   elsif(is_openbsd) {
      $user_o = "OpenBSD";
   }
   elsif(operating_system_is("SunOS")) {
      $user_o = "SunOS";
   }
   elsif(is_openwrt) {
      $user_o = "OpenWrt";
   }

   my $class = "Rex::User::" . $user_o;
   eval "use $class";

   if($@) {
   
      Rex::Logger::info("OS not supported");
      die("OS not supported");
   
   }

   return $class->new;

}

1;
