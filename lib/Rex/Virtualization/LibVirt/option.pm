#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::option;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

my $FUNC_MAP = {
   max_memory  => "setmaxmem",
   memory      => "setmem",
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

      unless(exists $FUNC_MAP->{$opt}) {
         Rex::Logger::info("$opt can't be set right now.");
         next;
      }

      my $func = $FUNC_MAP->{$opt};
      run "virsh $func $dom $val";
      if($? != 0) {
         Rex::Logger::info("Error setting $opt to $val on $dom ($@)");
      }

   }

}

1;

