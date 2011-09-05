#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Hardware::Network::FreeBSD;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Helper::Array;

sub get_network_devices {

   my @device_list = grep { $_=$1 if /^([a-z0-9]+)\:/i } run "ifconfig -a";

   @device_list = array_uniq(@device_list);
   return \@device_list;

}

sub get_network_configuration {
   
   my $devices = get_network_devices();

   my $device_info = {};

   for my $dev (@{$devices}) {

      my $ifconfig = run("LC_ALL=C ifconfig $dev");

      $device_info->{$dev} = {
         ip          => [ ( $ifconfig =~ m/inet (\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
         netmask     => [ ( $ifconfig =~ m/(netmask 0x|netmask )([a-f0-9]+)/ ) ]->[1],
         broadcast   => [ ( $ifconfig =~ m/broadcast (\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
         mac         => [ ( $ifconfig =~ m/(ether|address:|lladdr) (..?:..?:..?:..?:..?:..?)/ ) ]->[1],
      };

   }

   return $device_info;

}

1;
