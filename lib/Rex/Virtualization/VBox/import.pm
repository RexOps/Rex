#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::import;

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
   Rex::Logger::debug("importing: $dom -> ". $opt{file});

   run "VBoxManage import '" . $opt{file} . "' --vsys 0 --vmname '" . $dom . "'";
}

1;

