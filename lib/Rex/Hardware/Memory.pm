#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Memory;

use strict;
use warnings;

use Rex::Commands::Run;

sub get {
   my $free_str = [ grep { /^Mem:/ } split(/\n/, run("free -m")) ]->[0];

   my ($total, $used, $free, $shared, $buffers, $cached) = ($free_str =~ m/^Mem:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/);

   return { 
      total => $total,
      used  => $used,
      free  => $free,
      shared => $shared,
      buffers => $buffers,
      cached => $cached
   };
}

1;
