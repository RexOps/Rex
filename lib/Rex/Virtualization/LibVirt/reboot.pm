#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::reboot;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
   my ($class, $arg1, %opt) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my $dom = $arg1;
   Rex::Logger::debug("rebooting domain: $dom");

   unless($dom) {
      die("VM $dom not found.");
   }

   i_run "virsh reboot $dom";
   if($? != 0) {
      die("Error rebooting vm $dom");
   }

}

1;
