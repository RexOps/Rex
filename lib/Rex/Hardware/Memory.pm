#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Memory;

use strict;
use warnings;

use Rex::Hardware::Host;
use Rex::Commands::Run;
use Rex::Commands::Sysctl;

require Rex::Hardware;

sub get {

   if(my $ret = Rex::Hardware->cache("Memory")) {
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
         used => $conn->post("/os/memory/used")->{used},
         total => $conn->post("/os/memory/max")->{max},
         free => $conn->post("/os/memory/free")->{free},
      };
   }
   elsif($os eq "SunOS") {
      my @data = run "echo ::memstat | mdb -k";

      my ($free_cache) = grep { $_=$1 if /^Free \(cache[^\d]+\d+\s+(\d+)/ } @data;
      my ($free_list)  = grep { $_=$1 if /^Free \(freel[^\d]+\d+\s+(\d+)/ } @data;
      my ($page_cache) = grep { $_=$1 if /^Free \(freel[^\d]+\d+\s+(\d+)/ } @data;

      my $free = $free_cache + $free_list;
      #my ($total, $total_e) = grep { $_=$1 if /^Memory Size: (\d+) ([a-z])/i } run "prtconf";
      my ($total) = grep { $_=$1 if /^Total\s+\d+\s+(\d+)/ } @data;

      &$convert($free, "M");
      &$convert($total, "M");
      my $used = $total - $free;

      return {
         used => $used,
         total => $total,
         free => $free,
      };

   }
   elsif($os eq "OpenBSD") {
      my $mem_str  = run "top -d1 | grep Memory:";
      my $total_mem = sysctl("hw.physmem");

      my ($phys_mem, $p_m_ent, $virt_mem, $v_m_ent, $free, $f_ent) =
         ($mem_str =~m/(\d+)([a-z])\/(\d+)([a-z])[^\d]+(\d+)([a-z])/i);

      &$convert($phys_mem, $p_m_ent);
      &$convert($virt_mem, $v_m_ent);
      &$convert($free, $f_ent);

      return {
         used => $phys_mem + $virt_mem,
         total => $total_mem,
         free => $free,
      };

   }
   elsif($os eq "NetBSD") {
      my $mem_str  = run "top -d1 | grep Memory:";
      my $total_mem = sysctl("hw.physmem");

      my ($active, $a_ent, $wired, $w_ent, $exec, $e_ent, $file, $f_ent, $free, $fr_ent) = 
         ($mem_str =~ m/(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])/i);

      &$convert($active, $a_ent);
      &$convert($wired, $w_ent);
      &$convert($exec, $e_ent);
      &$convert($file, $f_ent);
      &$convert($free, $fr_ent);

      return {
         total => $total_mem,
         used => $active + $exec + $file + $wired,
         free => $free,
         file => $file,
         exec => $exec,
         wired => $wired,
      };

   }
   elsif($os =~ /FreeBSD/) {
      my $mem_str  = run "top -d1 | grep Mem:";
      my $total_mem = sysctl("hw.physmem");

      my ($active, $a_ent, $inactive, $i_ent, $wired, $w_ent, $cache, $c_ent, $buf, $b_ent, $free, $f_ent) = 
            ($mem_str =~ m/(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])/i);

      &$convert($active, $a_ent);
      &$convert($inactive, $i_ent);
      &$convert($wired, $w_ent);
      &$convert($cache, $c_ent);
      &$convert($buf, $b_ent);
      &$convert($free, $f_ent);

      return {
         total => $total_mem,
         used => $active + $inactive + $wired,
         free  => $free,
         cached => $cache,
         buffers => $buf,
      };
   }
   else {
      # default for linux
      my $free_str = [ grep { /^Mem:/ } split(/\n/, run("LC_ALL=C free -m")) ]->[0];

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
}

1;
