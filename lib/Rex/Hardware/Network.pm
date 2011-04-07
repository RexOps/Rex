#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Network;

use strict;
use warnings;

use Data::Dumper;

use Rex::Commands::Run;

sub get {

   return {
 
      networkdevices => get_network_devices(),
      networkconfiguration => get_network_configuration(),

   };

}

sub get_network_devices {

   my @device_list;

   my @proc_net_dev = grep  { ! /^$/ } map { $1 if /^\s+([^:]+)\:/ } split(/\n/, run("cat /proc/net/dev"));

   for my $dev (@proc_net_dev) {
      my $ifconfig = run("ifconfig $dev");
      if($ifconfig =~ m/Link encap:Ethernet/m) {
         push(@device_list, $dev);
      }
   }

   return \@device_list;

}

sub get_network_configuration {
   
   my $devices = get_network_devices();

   my $device_info = {};

   for my $dev (@{$devices}) {

      my $ifconfig = run("ifconfig $dev");
      $device_info->{$dev} = {
         ip          => [ ( $ifconfig =~ m/inet addr:(\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
         netmask     => [ ( $ifconfig =~ m/Mask:(\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
         broadcast   => [ ( $ifconfig =~ m/Bcast:(\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
         mac         => [ ( $ifconfig =~ m/HWaddr (..:..:..:..:..:..)/ ) ]->[0],
      };

   }

   return $device_info;

}


1;
