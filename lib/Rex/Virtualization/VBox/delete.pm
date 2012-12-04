#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::delete;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

sub execute {
   my ($class, $arg1) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my $dom = $arg1;
   Rex::Logger::debug("deleting domain: $dom");

   unless($dom) {
      die("VM $dom not found.");
   }

   run "virsh undefine $dom";
   if($? != 0) {
      die("Error destroying vm $dom");
   }

}

1;


