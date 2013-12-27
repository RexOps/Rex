#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::shutdown;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
   my ($class, $arg1, %opt) = @_;

   unless($arg1) {
      die("You have to define the container ID!");
   }

   my $dom = $arg1;
   Rex::Logger::debug("shutdowning container $dom");

   unless($dom) {
      die("VM $dom not found.");
   }

   i_run "docker stop \"$dom\"";
   if($? != 0) {
      die("Error shutdowning container $dom");
   }

}

1;


