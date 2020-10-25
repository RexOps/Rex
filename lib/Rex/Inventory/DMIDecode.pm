#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::DMIDecode;

use 5.010001;
use strict;
use warnings;
use Data::Dumper;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Inventory::DMIDecode::BaseBoard;
use Rex::Inventory::DMIDecode::Bios;
use Rex::Inventory::DMIDecode::CPU;
use Rex::Inventory::DMIDecode::Memory;
use Rex::Inventory::DMIDecode::MemoryArray;
use Rex::Inventory::DMIDecode::SystemInformation;
use Rex::Commands::Run;
use Rex::Helper::Run;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->_read_dmidecode();

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

  return Rex::Inventory::DMIDecode::BaseBoard->new( dmi => $self );
}

sub get_bios {
  my ($self) = @_;

  return Rex::Inventory::DMIDecode::Bios->new( dmi => $self );
}

sub get_system_information {
  my ($self) = @_;

  return Rex::Inventory::DMIDecode::SystemInformation->new( dmi => $self );
}

sub get_cpus {

  my ($self) = @_;
  my @cpus   = ();
  my $tree   = $self->get_tree("Processor Information");
  my $idx    = 0;
  for my $cpu ( @{$tree} ) {
    if ( $cpu->{"Status"} =~ m/Populated/ ) {
      push( @cpus,
        Rex::Inventory::DMIDecode::CPU->new( dmi => $self, index => $idx ) );
    }
    ++$idx;
  }

  return @cpus;

}

sub get_memory_modules {

  my ($self) = @_;
  my @mems   = ();
  my $tree   = $self->get_tree("Memory Device");
  my $idx    = 0;
  for my $mem ( @{$tree} ) {
    if ( $mem->{"Size"} =~ m/\d+/ ) {
      push( @mems,
        Rex::Inventory::DMIDecode::Memory->new( dmi => $self, index => $idx ) );
    }
    ++$idx;
  }

  return @mems;

}

sub get_memory_arrays {

  my ($self) = @_;
  my @mems   = ();
  my $tree   = $self->get_tree("Physical Memory Array");
  my $idx    = 0;
  for my $mema ( @{$tree} ) {
    push(
      @mems,
      Rex::Inventory::DMIDecode::MemoryArray->new(
        dmi   => $self,
        index => $idx
      )
    );
    ++$idx;
  }

  return @mems;

}

sub _read_dmidecode {

  my ($self) = @_;

  my @lines;
  if ( $self->{lines} ) {
    @lines = @{ $self->{lines} };
  }
  else {
    unless ( can_run("dmidecode") ) {
      Rex::Logger::debug("Please install dmidecode on the target system.");
      return;
    }

    eval { @lines = i_run "dmidecode"; };

    if ($@) {
      Rex::Logger::debug("Error running dmidecode");
      return;
    }
  }
  chomp @lines;

  my %section     = ();
  my $section     = "";
  my $new_section = 0;
  my $sub_section = "";

  for my $l (@lines) {

    next if $l =~ m/^Handle/;
    next if $l =~ m/^#/;
    next if $l =~ m/^SMBIOS/;
    next if $l =~ m/^$/;
    last if $l =~ m/^End Of Table$/;

    # for openbsd
    $l =~ s/      /\t/g;

    unless ( substr( $l, 0, 1 ) eq "\t" ) {
      $section     = $l;
      $new_section = 1;
      next;
    }

    my $line = $l;
    $line =~ s/^\t+//g;
    $line =~ s/\s+$//g;

    next if $l =~ m/^$/;

    if ( $l =~ m/^\t[a-zA-Z0-9]/ ) {
      if ( exists $section{$section} && !ref( $section{$section} ) ) {
        my $content = $section{$section};
        $section{$section} = [];
        my @arr = ();
        my ( $key, $val ) = split( /: /, $line, 2 );
        $key =~ s/:$//;
        $sub_section = $key;

        #push (@{$section{$section}}, $content);
        push( @{ $section{$section} }, { $key => $val } );
        $new_section = 0;
        next;
      }
      elsif ( exists $section{$section} && ref( $section{$section} ) ) {
        if ($new_section) {
          push( @{ $section{$section} }, {} );
          $new_section = 0;
        }
        my ( $key, $val ) = split( /: /, $line, 2 );
        $key =~ s/:$//;
        $sub_section = $key;
        my $href = $section{$section}->[-1];

        #push (@{$section{$section}}, {$key => $val});
        $href->{$key} = $val;
        next;
      }

      my ( $key, $val ) = split( /: /, $line, 2 );
      if ( !$val ) { $key =~ s/:$//; }
      $sub_section       = $key;
      $section{$section} = [ { $key => $val } ];
      $new_section       = 0;
    }
    elsif ( $l =~ m/^\t\t[a-zA-Z0-9]/ ) {
      my $href = $section{$section}->[-1];
      if ( !ref( $href->{$sub_section} ) ) {
        $href->{$sub_section} = [];
      }

      push( @{ $href->{$sub_section} }, $line );
    }

  }

  $self->{"__dmi"} = \%section;

}

1;
