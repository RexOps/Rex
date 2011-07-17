#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory;

use strict;
use warnings;

use Rex::Inventory::DMIDecode;
use Rex::Inventory::Hal;
use Rex::Commands::Network;
use Rex::Commands::Run;
use Rex::Commands::Gather;

use Rex::Inventory::HP::ACU;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub get {

   my ($self) = @_;
   
   my $dmi = Rex::Inventory::DMIDecode->new;
   my ($base_board, $bios, @cpus, @dimms, @mem_arrays, $sys_info);

   $base_board = $dmi->get_base_board;
   $bios       = $dmi->get_bios;
   @cpus       = $dmi->get_cpus;
   @dimms      = $dmi->get_memory_modules;
   @mem_arrays = $dmi->get_memory_arrays;
   $sys_info   = $dmi->get_system_information;

   my $hal = Rex::Inventory::Hal->new;
   my @net_devs = $hal->get_network_devices;
   my @storage  = $hal->get_storage_devices;
   my @volumes  = $hal->get_storage_volumes;

   my @routes     = route;
   my @netstat    = netstat;
   my $default_gw = default_gateway;

   my @raid_controller;
   my @raid_logical_drives;
   my %raid_shelfs;
   if(my $hp_raid = Rex::Inventory::HP::ACU->get()) {
      # hp raid entdeckt
      for my $key (keys %{$hp_raid}) {
         push(@raid_controller, {
                     type => $hp_raid->{$key}->{"description"},
                     model => $hp_raid->{$key}->{"model"},
                     serial_number => $hp_raid->{$key}->{"serial_number"},
                     cache_status => $hp_raid->{$key}->{"cache_status"},
                  });

         for my $shelf (keys %{$hp_raid->{$key}->{"array"}}) {
            my $shelf_data = $hp_raid->{$key}->{"array"}->{$shelf};
            $raid_shelfs{$shelf} = {
                  type => $shelf_data->{"interface_type"},
                  status => $shelf_data->{"status"},
               };

            for my $l_drive (keys %{$hp_raid->{$key}->{"array"}->{$shelf}->{"logical_drive"}}) {
               my $l_drive_data = $hp_raid->{$key}->{"array"}->{$shelf}->{"logical_drive"}->{$l_drive};
               my ($size) = ($l_drive_data->{"size"} =~ m/^([0-9\.]+)/);
               push(@raid_logical_drives, {
                     status => $l_drive_data->{"status"},
                     raid_level => $l_drive_data->{"fault_tolerance"},
                     size => sprintf("%i", $size * 1024 * 1024 * 1024),
                     dev => $l_drive_data->{"disk_name"},
                     shelf => $shelf,
                  });
            }
         }
      }
   }

   return {
      base_board  => ($base_board?$base_board->get_all():{}),
      bios        => $bios->get_all(),
      system_info => $sys_info->get_all(),
      cpus        => sub { my $ret = []; push(@{$ret}, $_->get_all()) for @cpus; return $ret; }->(),
      dimms       => sub { my $ret = []; push(@{$ret}, $_->get_all()) for @dimms; return $ret; }->(),
      mem_arrays  => sub { my $ret = []; push(@{$ret}, $_->get_all()) for @mem_arrays; return $ret; }->(),
      net         => sub { my $ret = []; push(@{$ret}, $_->get_all()) for @net_devs; return $ret; }->(),
      storage     => sub { my $ret = []; push(@{$ret}, $_->get_all()) for @storage; return $ret; }->(),
      volumes     => sub { my $ret = []; push(@{$ret}, $_->get_all()) for @volumes; return $ret; }->(),
      raid        => {
         controller => \@raid_controller,
         shelfs => \%raid_shelfs,
         drives => \@raid_logical_drives,
      },
      configuration => {
         network => {
            routes                => \@routes,
            current_connections   => \@netstat,
            default_gateway       => $default_gw,
            current_configuration => network_interfaces(),
         },
         host    => {
            name   => [ run "hostname" ]->[0],
            domain => [ run "hostname -d" || qw() ]->[0],
            kernel => [ run "uname -r" || qw() ]->[0],
         },
      },
   };

}

1;
