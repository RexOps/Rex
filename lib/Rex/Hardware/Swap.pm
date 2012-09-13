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

require Rex::Hardware;

sub get {

   if(my $ret = Rex::Hardware->cache("Swap")) {
      return $ret;
   }

   my $os = Rex::Hardware::Host::get_operating_system();

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


   if($os eq "Windows") {
      my $conn = Rex::get_current_connection()->{conn};
      return {
         used => $conn->post("/os/swap/used")->{used},
         total => $conn->post("/os/swap/max")->{max},
         free => $conn->post("/os/swap/free")->{free},
      };
   }
   elsif($os eq "SunOS") {
      my ($swap_str) = run("swap -s");

      my ($used, $u_ent, $avail, $a_ent) = ($swap_str =~ m/(\d+)([a-z]) used, (\d+)([a-z]) avail/);

      &$convert($used, uc($u_ent));
      &$convert($avail, uc($a_ent));

      return {
         total => $used + $avail,
         used => $used,
         free => $avail,
      };
   }
   elsif($os eq "OpenBSD") {
      my $swap_str = run "top -d1 | grep Swap:";

      my ($used, $u_ent, $total, $t_ent) = ($swap_str =~ m/Swap: (\d+)([a-z])\/(\d+)([a-z])/i);

      &$convert($used, $u_ent);
      &$convert($total, $t_ent);

      return {
         total => $total,
         used  => $used,
         free  => $total - $used,
      };
   }
   elsif($os eq "NetBSD") {
      my $swap_str = run "top -d1 | grep Swap:";

      my ($total, $t_ent, $free, $f_ent) = 
            ($swap_str =~ m/(\d+)([a-z])[^\d]+(\d+)([a-z])/i);

      &$convert($total, $t_ent);
      &$convert($free, $f_ent);

      return {
         total => $total,
         used => $total-$free,
         free => $free,
      };

   }
   elsif($os =~ /FreeBSD/) {
      my $swap_str = run "top -d1 | grep Swap:";

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
