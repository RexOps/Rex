#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Commands::Iptables;

require Exporter;

use base qw(Exporter);

use vars qw(@EXPORT);

use Rex::Commands::Sysctl;
use Rex::Commands::Run;

use Rex::Logger;

@EXPORT = qw(iptables is_nat_gateway);

sub iptables {
   
   my (%option) = @_;

   my $cmd = "/sbin/iptables ";

   if(exists $option{"open"}) {

      $cmd .= "-t filter -I INPUT ";

      # net device given?
      if(exists $option{"dev"}) {
         $cmd .= " -i " . $option{"dev"};
      }

      # proto given?
      if(exists $option{"proto"}) {
         $cmd .= " -p " . $option{"proto"};
         $cmd .= " -m " . $option{"proto"};
      }

      unless($option{"open"} eq "all") {
         for my $port (@{$option{"open"}}) {
            my $subcmd = $cmd;

            $subcmd .= " --dport $port ";
            $subcmd .= " -j ACCEPT ";

            run "$subcmd";
            if($? != 0) {
               Rex::Logger::info("Error setting iptable rule: $subcmd");
            }
         }
      }
      else {

         $cmd .= " -j ACCEPT ";

         run "$cmd";
         if($? != 0) {
            Rex::Logger::info("Error setting iptable rule: $cmd");
         }

      }

   }
   elsif(exists $option{"close"}) {
      $cmd .= "-t filter -A INPUT ";

      # net device given?
      if(exists $option{"dev"}) {
         $cmd .= " -i " . $option{"dev"};
      }

      # proto given?
      if(exists $option{"proto"}) {
         $cmd .= " -p " . $option{"proto"};
         $cmd .= " -m " . $option{"proto"};
      }

      unless($option{"close"} eq "all") {
         for my $port (@{$option{"close"}}) {
            my $subcmd = $cmd;

            $subcmd .= " --dport $port ";
            $subcmd .= " -j REJECT --reject-with icmp-host-unreachable ";

            run "$subcmd";
            if($? != 0) {
               Rex::Logger::info("Error setting iptable rule: $subcmd");
            }
         }
      }
      else {

         $cmd .= " -j REJECT --reject-with icmp-host-unreachable ";

         run "$cmd";
         if($? != 0) {
            Rex::Logger::info("Error setting iptable rule: $cmd");
         }

      }

   }
   elsif(exists $option{"redirect"}) {
      $cmd .= " -t nat ";

      if($option{"to"} =~ m/\:(\d+)$/) {

         $cmd .= " -I OUTPUT ";

         if(exists $option{"destination"}) {
            $cmd .= " -d " . $option{"destination"} . "/32 ";
         }

         if(exists $option{"source"}) {
            $cmd .= " -s " . $option{"source"} . "/32 ";
         }

         # proto given?
         if(exists $option{"proto"}) {
            $cmd .= " -p " . $option{"proto"};
            $cmd .= " -m " . $option{"proto"};
         }

         if(exists $option{"dev"}) {
            $cmd .= " -o " . $option{"dev"};
         }

         $cmd .= " --dport " . $option{"redirect"};

         $cmd .= " -j DNAT ";

         $cmd .= " --to-destination " . $option{"to"};

      }
      else {

         $cmd .= " -I PREROUTING ";

         if(exists $option{"destination"}) {
            $cmd .= " -d " . $option{"destination"} . "/32 ";
         }

         if(exists $option{"source"}) {
            $cmd .= " -s " . $option{"source"} . "/32 ";
         }

         if(exists $option{"dev"}) {
            $cmd .= " -i " . $option{"dev"};
         }

         # proto given?
         if(exists $option{"proto"}) {
            $cmd .= " -p " . $option{"proto"};
            $cmd .= " -m " . $option{"proto"};
         }

         $cmd .= " --dport " . $option{"redirect"};

         $cmd .= " -j REDIRECT ";
         $cmd .= " --to-ports " . $option{"to"};
      
      }

      run $cmd;
      if($? != 0) {
         Rex::Logger::info("Error setting iptable rule: $cmd");
      }

   }

}

sub is_nat_gateway {

   Rex::Logger::debug("Changing this system to a nat gateway.");

   if(can_run("ip")) {

      my ($default_line) = run "/sbin/ip r |grep ^default";
      my ($dev) = ($default_line =~ m/dev ([a-z0-9]+)/i);
      Rex::Logger::debug("Default GW Device is $dev");

      sysctl "net.ipv4.ip_forward" => 1;
      run "/sbin/iptables -t nat -A POSTROUTING -o $dev -j MASQUERADE";

      if($? != 0) {
         Rex::Logger::info("Error setting iptable rule: $cmd");
      }

      return $?==0?1:0;

   }
   else {

      Rex::Logger::info("No /sbin/ip found.");

   }

}

1;
