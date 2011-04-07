#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Swap;

use strict;
use warnings;

use Rex::Commands::Run;

sub get {
   my $free_str = [ grep { /^Swap:/ } split(/\n/, run("free -m")) ]->[0];

   my ($total, $used, $free) = ($free_str =~ m/^Swap:\s+(\d+)\s+(\d+)\s+(\d+)$/);

   return { 
      total => $total,
      used  => $used,
      free  => $free,
   };
}



1;
