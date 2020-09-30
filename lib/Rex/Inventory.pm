#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory;

use strict;
use warnings;

# VERSION

use Rex::Inventory::DMIDecode;
use Rex::Inventory::Hal;
use Rex::Inventory::Proc;
use Rex::Commands::Network;
use Rex::Commands::Run;
use Rex::Commands::Gather;
use Rex::Commands::LVM;
use Rex::Commands::Fs;

use Rex::Inventory::HP::ACU;
use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub get {

  my ($self) = @_;

  my $dmi = Rex::Inventory::DMIDecode->new;
  my ( $base_board, $bios, @cpus, @dimms, @mem_arrays, $sys_info );

  $base_board = $dmi->get_base_board;
  $bios       = $dmi->get_bios;
  @cpus       = $dmi->get_cpus;
  @dimms      = $dmi->get_memory_modules;
  @mem_arrays = $dmi->get_memory_arrays;
  $sys_info   = $dmi->get_system_information;

  my $hal = {};
  my ( @net_devs, @storage, @volumes );

  eval {
    $hal = Rex::Inventory::Hal->new;

    @net_devs = $hal->get_network_devices;
    @storage  = $hal->get_storage_devices;
    @volumes  = $hal->get_storage_volumes;
  };

  eval {
    if ( scalar @cpus == 0 ) {

      # get cpu info from /proc
      if ( is_dir("/proc") ) {
        Rex::Logger::info(
          "Got no cpu information from dmidecode. Falling back to /proc/cpuinfo"
        );
        my $proc_i = Rex::Inventory::Proc->new;
        @cpus = @{ $proc_i->get_cpus };
      }
    }
  };

  my @routes     = route;
  my @netstat    = netstat;
  my $default_gw = default_gateway;

  my ( @pvs, @vgs, @lvs );
  eval {
    @pvs = pvs;
    @vgs = vgs;
    @lvs = lvs;
  };

  my @raid_controller;
  eval {
    if ( my $hp_raid = Rex::Inventory::HP::ACU->get() ) {

      # hp raid entdeckt
      for my $key ( keys %{$hp_raid} ) {

        my %raid_shelfs;
        for my $shelf ( keys %{ $hp_raid->{$key}->{"array"} } ) {
          my $shelf_data = $hp_raid->{$key}->{"array"}->{$shelf};

          my @raid_logical_drives;
          for my $l_drive (
            keys %{ $hp_raid->{$key}->{"array"}->{$shelf}->{"logical_drive"} } )
          {
            my $l_drive_data =
              $hp_raid->{$key}->{"array"}->{$shelf}->{"logical_drive"}
              ->{$l_drive};
            my ($size) = ( $l_drive_data->{"size"} =~ m/^([0-9\.]+)/ );
            my $multi = 1024 * 1024 * 1024;
            if ( $l_drive_data->{"size"} =~ m/TB$/ ) {
              $multi *= 1024;
            }

            push(
              @raid_logical_drives,
              {
                status     => ( $l_drive_data->{"status"} eq "OK" ? 1 : 0 ),
                raid_level => $l_drive_data->{"fault_tolerance"},
                size       => sprintf( "%i", $size * $multi ),
                dev        => $l_drive_data->{"disk_name"},
                shelf      => $shelf,
              }
            );
          }

          $raid_shelfs{$shelf} = {
            type           => $shelf_data->{"interface_type"},
            status         => ( $shelf_data->{"status"} eq "OK" ? 1 : 0 ),
            logical_drives => \@raid_logical_drives,
          };

        }

        push(
          @raid_controller,
          {
            type          => $hp_raid->{$key}->{"description"},
            model         => $hp_raid->{$key}->{"model"},
            serial_number => $hp_raid->{$key}->{"serial_number"},
            cache_status  =>
              ( $hp_raid->{$key}->{"cache_status"} eq "OK" ? 1 : 0 ),
            shelfs => \%raid_shelfs,
          }
        );

      }
    }
  };

  my ($fusion_inventory_xmlref);
  if ( can_run("fusioninventory-agent") ) {
    require XML::Simple;
    my $xml              = XML::Simple->new;
    my $fusion_inventory = run "fusioninventory-agent --stdout 2>/dev/null";
    $fusion_inventory_xmlref = $xml->XMLin($fusion_inventory);
  }

  return {
    base_board  => ( $base_board ? $base_board->get_all() : {} ),
    bios        => $bios->get_all(),
    system_info => $sys_info->get_all(),
    cpus        => sub {
      my $ret = [];
      push( @{$ret}, ( ref $_ ne "HASH" ? $_->get_all() : $_ ) ) for @cpus;
      return $ret;
    }
      ->(),
    dimms => sub {
      my $ret = [];
      push( @{$ret}, $_->get_all() ) for @dimms;
      return $ret;
    }
      ->(),
    mem_arrays => sub {
      my $ret = [];
      push( @{$ret}, $_->get_all() ) for @mem_arrays;
      return $ret;
    }
      ->(),
    net => sub {
      my $ret = [];
      push( @{$ret}, $_->get_all() ) for @net_devs;
      return $ret;
    }
      ->(),
    storage => sub {
      my $ret = [];
      push( @{$ret}, $_->get_all() ) for @storage;
      return $ret;
    }
      ->(),
    volumes => sub {
      my $ret = [];
      push( @{$ret}, $_->get_all() ) for @volumes;
      return $ret;
    }
      ->(),
    raid => {
      controller => \@raid_controller,
    },
    lvm => {
      physical_volumes => \@pvs,
      volume_groups    => \@vgs,
      logical_volumes  => \@lvs,
    },
    configuration => {
      network => {
        routes                => \@routes,
        current_connections   => \@netstat,
        default_gateway       => $default_gw,
        current_configuration => network_interfaces(),
      },
      host => {
        name   => [ run "hostname -s" ]->[0],
        domain => [ run "hostname -d" || qw() ]->[0],
        kernel => [ run "uname -r"    || qw() ]->[0],
      },
    },
    fusion_inventory => $fusion_inventory_xmlref,
  };

}

1;
