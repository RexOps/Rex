#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Swap;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Hardware::Host;

sub get {

   my $os = Rex::Hardware::Host::get_operating_system();

   if($os =~ /BSD/) {
      my $swap_str = run "top -d1 | grep Swap:";

      my $convert = sub {

         if($_[1] eq "G") {
            $_[0] = $_[0] * 1024 * 1024 * 1024;
         }
         elsif($_[1] eq "M") {
            $_[0] = $_[0] * 1024 * 1024;
         }
         elsif($_[1] eq "K") {
            $_[0] = $_[0] * 1024;
         }

      };

      my ($total, $t_ent, $used, $u_ent, $free, $f_ent) = 
            ($swap_str =~ m/(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])/i);

      &$convert($total, $t_ent);
      &$convert($used, $u_ent);
      &$convert($free, $f_ent);

      return {
         total => $total,
         used => $used,
         free => $free,
      };
   }
   else {
      # linux as default
      my $free_str = [ grep { /^Swap:/ } split(/\n/, run("LC_ALL=C free -m")) ]->[0];

      my ($total, $used, $free) = ($free_str =~ m/^Swap:\s+(\d+)\s+(\d+)\s+(\d+)$/);

      return { 
         total => $total,
         used  => $used,
         free  => $free,
      };

   }
}



1;
