#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::option;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

my $FUNC_MAP = {
   max_memory  => "memory",
   memory      => "memory",
};

sub execute {
   my ($class, $arg1, %opt) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my $dom = $arg1;
   Rex::Logger::debug("setting some options for: $dom");

   for my $opt (keys %opt) {
      my $val = $opt{$opt};

      my $func;
      unless(exists $FUNC_MAP->{$opt}) {
         Rex::Logger::debug("$opt unknown. using as option for VBoxManage.");
         $func = $opt;
      }
      else {
         $func = $FUNC_MAP->{$opt};
      }

      run "VBoxManage modifyvm \"$dom\" --$func \"$val\"";
      if($? != 0) {
         Rex::Logger::info("Error setting $opt to $val on $dom ($@)", "warn");
      }

   }

}

1;

