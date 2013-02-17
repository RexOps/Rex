#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::start;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

sub execute {
   my ($class, $arg1, %opt) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my $dom = $arg1;
   Rex::Logger::debug("starting domain: $dom");

   unless($dom) {
      die("VM $dom not found.");
   }

   my $virt_settings = Rex::Config->get("virtualization");
   my $headless = 0;
   if(ref($virt_settings)) {
      if(exists $virt_settings->{headless} && $virt_settings->{headless}) {
         $headless = 1;
      }
   }

   if($headless) {
      run "VBoxHeadless --startvm \"$dom\"";
   }
   else {
      run "VBoxManage startvm \"$dom\"";
   }

   if($? != 0) {
      die("Error starting vm $dom");
   }

}

1;
