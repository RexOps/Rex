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
   };

}

1;
