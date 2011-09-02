#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Network;

use strict;
use warnings;

use Data::Dumper;

use Rex::Logger;
use Rex::Helper::Array;
use Rex::Commands::Run;
use Rex::Hardware::Host;

sub get {

   return {
 
      networkdevices => get_network_devices(),
      networkconfiguration => get_network_configuration(),

   };

}

sub get_network_devices {

   my $os = Rex::Hardware::Host::get_operating_system();

   if($os =~ m/BSD/ || $os eq "SunOS") {
      my @device_list = grep { $_=$1 if /^([a-z0-9]+)\:/i } run "ifconfig -a";

      @device_list = array_uniq(@device_list);
      return \@device_list;
   }
   else {
      #default is linux
      my @device_list;

      my @proc_net_dev = grep  { ! /^$/ } map { $1 if /^\s+([^:]+)\:/ } split(/\n/, run("cat /proc/net/dev"));

      for my $dev (@proc_net_dev) {
         my $ifconfig = run("ifconfig $dev");
         if($ifconfig =~ m/Link encap:Ethernet/m) {
            push(@device_list, $dev);
         }
      }

      @device_list = array_uniq(@device_list);
      return \@device_list;
   }
}

sub get_network_configuration {
   
   my $devices = get_network_devices();

   my $device_info = {};

   for my $dev (@{$devices}) {

      my $ifconfig = run("LC_ALL=C ifconfig $dev");

      my $os = Rex::Hardware::Host::get_operating_system();

      if($os =~ m/BSD/ || $os eq "SunOS") {
         $device_info->{$dev} = {
            ip          => [ ( $ifconfig =~ m/inet (\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
            netmask     => [ ( $ifconfig =~ m/(netmask 0x|netmask )([a-f0-9]+)/ ) ]->[1],
            broadcast   => [ ( $ifconfig =~ m/broadcast (\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
            mac         => [ ( $ifconfig =~ m/(ether|address:|lladdr) (..?:..?:..?:..?:..?:..?)/ ) ]->[1],
         };
      }
      else {
         $device_info->{$dev} = {
            ip          => [ ( $ifconfig =~ m/inet addr:(\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
            netmask     => [ ( $ifconfig =~ m/Mask:(\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
            broadcast   => [ ( $ifconfig =~ m/Bcast:(\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
            mac         => [ ( $ifconfig =~ m/HWaddr (..:..:..:..:..:..)/ ) ]->[0],
         };
      }

   }

   return $device_info;

}


1;
