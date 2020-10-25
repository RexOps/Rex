#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::SMBios;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;
use Rex::Logger;
use Rex::Commands::Run;
use Rex::Helper::Run;

use Rex::Inventory::SMBios::BaseBoard;
use Rex::Inventory::SMBios::Bios;
use Rex::Inventory::SMBios::CPU;
use Rex::Inventory::SMBios::Memory;
use Rex::Inventory::SMBios::MemoryArray;
use Rex::Inventory::SMBios::SystemInformation;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->_read_smbios();

  return $self;
}

sub get_tree {
  my ( $self, $section ) = @_;

  if ($section) {
    return $self->{"__dmi"}->{$section};
  }

  return $self->{"__dmi"};
}

sub get_base_board {
  my ($self) = @_;
  return Rex::Inventory::SMBios::BaseBoard->new( dmi => $self );
}

sub get_bios {
  my ($self) = @_;
  return Rex::Inventory::SMBios::Bios->new( dmi => $self );
}

sub get_system_information {
  my ($self) = @_;
  return Rex::Inventory::SMBios::SystemInformation->new( dmi => $self );
}

sub get_cpus {

  my ($self) = @_;
  my @cpus   = ();
  my $tree   = $self->get_tree("processor");
  my $idx    = 0;
  for my $cpu ( @{$tree} ) {
    if ( $cpu->{"Socket Status"} =~ m/Populated/ ) {
      push( @cpus,
        Rex::Inventory::SMBios::CPU->new( dmi => $self, index => $idx ) );
    }
    ++$idx;
  }

  return @cpus;

}

sub get_memory_modules {

  my ($self) = @_;
  my @mems   = ();
  my $tree   = $self->get_tree("memory device");
  my $idx    = 0;
  for my $mem ( @{$tree} ) {
    if ( $mem->{"Size"} =~ m/\d+/ ) {
      push( @mems,
        Rex::Inventory::SMBios::Memory->new( dmi => $self, index => $idx ) );
    }
    ++$idx;
  }

  return @mems;

}

sub get_memory_arrays {

  my ($self) = @_;
  my @mems   = ();
  my $tree   = $self->get_tree("physical memory array");
  my $idx    = 0;
  for my $mema ( @{$tree} ) {
    push( @mems,
      Rex::Inventory::SMBios::MemoryArray->new( dmi => $self, index => $idx ) );
    ++$idx;
  }

  return @mems;

}

sub _read_smbios {
  my ($self) = @_;

  my @data = i_run( "smbios", fail_ok => 1 );

  my ( $current_section, %section, $key, $val, %cur_data );
  for my $line (@data) {
    next if ( $line =~ /^$/ );
    next if ( $line =~ /^\s*$/ );
    next if ( $line =~ /^ID/ );

    if ( $line =~ m/^\d/ ) {
      push( @{ $section{$current_section} }, {%cur_data} ) if (%cur_data);

      ($current_section) = ( $line =~ m/\(([^\)]+)\)/ );

      if ( !exists $section{$current_section} ) {
        $section{$current_section} = [];
      }

      %cur_data = ();
      next;
    }

    # outer section
    if ( $line =~ /^\s\s[a-z]/i ) {
      $line =~ s/^\s*//;
      ( $key, $val ) = split( /: /, $line );
      $cur_data{$key} = $val;
    }
    elsif ( $line =~ /^\t[a-z]/i ) {
      if ( !ref( $cur_data{$key} ) ) {
        $cur_data{$key} = [];
      }

      $line =~ s/^\s*//;
      push( @{ $cur_data{$key} }, $line );
    }

  }

  # push the last
  push( @{ $section{$current_section} }, {%cur_data} );

  $self->{"__dmi"} = \%section;
}

1;
