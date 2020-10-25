#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::HP::ACU;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Commands::Run;
use Rex::Helper::Run;

sub get {

  if ( can_run("hpacucli") ) {
    my @lines = i_run "/usr/sbin/hpacucli controller all show config detail",
      fail_ok => 1;
    my $ret = parse_config(@lines);
    return $ret;
  }
  else {
    return 0;
  }

}

#
# The bellow code is from Parse::HP::ACU
#
# Copyright 2010 Jeremy Cole.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either: the GNU General Public License as published
# by the Free Software Foundation; or the Artistic License.
#
# See http://dev.perl.org/licenses/ for more information.
#
sub parse_config {
  my (@lines) = @_;

  my $controller             = {};
  my $current_controller     = 0;
  my $current_array          = undef;
  my $current_logical_drive  = undef;
  my $current_mirror_group   = undef;
  my $current_physical_drive = undef;

LINE: for my $line (@lines) {
    chomp $line;

    next if ( $line =~ /^$/ );

    if ( $line !~ /^[ ]+/ ) {
      $current_controller                = $current_controller + 1;
      $current_array                     = undef;
      $current_logical_drive             = undef;
      $current_mirror_group              = undef;
      $current_physical_drive            = undef;
      $controller->{$current_controller} = {};
      $controller->{$current_controller}->{'description'} = $line;
      next;
    }

    next if ( !defined($current_controller) );

    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    $line =~ s/[ ]+/ /g;

    if ( $line =~ /unassigned/ ) {
      $current_array                                     = "unassigned";
      $current_logical_drive                             = undef;
      $current_mirror_group                              = undef;
      $current_physical_drive                            = undef;
      $controller->{$current_controller}->{'unassigned'} = {};
      $controller->{$current_controller}->{'unassigned'}->{'physical_drive'} =
        {};
      next;
    }

    if ( $line =~ /Array: ([A-Z]+)/ ) {
      $current_array                                                  = $1;
      $current_logical_drive                                          = undef;
      $current_mirror_group                                           = undef;
      $current_physical_drive                                         = undef;
      $controller->{$current_controller}->{'array'}->{$current_array} = {};
      $controller->{$current_controller}->{'array'}->{$current_array}
        ->{'logical_drive'} = {};
      $controller->{$current_controller}->{'array'}->{$current_array}
        ->{'physical_drive'} = {};
      next;
    }

    if ( $line =~ /Logical Drive: ([0-9]+)/ ) {
      $current_logical_drive  = $1;
      $current_physical_drive = undef;
      $current_mirror_group   = undef;
      $controller->{$current_controller}->{'array'}->{$current_array}
        ->{'logical_drive'}->{$current_logical_drive} = {};
      $controller->{$current_controller}->{'array'}->{$current_array}
        ->{'logical_drive'}->{$current_logical_drive}->{'mirror_group'} = {};
      next;
    }

    if ( $line =~ /physicaldrive ([0-9IC:]+)/ and $line !~ /port/ ) {
      $current_logical_drive  = undef;
      $current_physical_drive = $1;
      $current_mirror_group   = undef;
      if ( $current_array eq 'unassigned' ) {
        $controller->{$current_controller}->{'unassigned'}->{'physical_drive'}
          ->{$current_physical_drive} = {};
      }
      else {
        $controller->{$current_controller}->{'array'}->{$current_array}
          ->{'physical_drive'}->{$current_physical_drive} = {};
      }
      next;
    }

    if ( $line =~ /Mirror Group ([0-9]+):/ ) {
      $current_mirror_group = $1;
      $controller->{$current_controller}->{'array'}->{$current_array}
        ->{'logical_drive'}->{$current_logical_drive}->{'mirror_group'}
        ->{$current_mirror_group} = [];
      next;
    }

    if (  defined($current_array)
      and defined($current_logical_drive)
      and defined($current_mirror_group) )
    {
      if ( $line =~ /physicaldrive ([0-9IC:]+) \(/ ) {
        my $current_mirror_group_list =
          $controller->{$current_controller}->{'array'}->{$current_array}
          ->{'logical_drive'}->{$current_logical_drive}->{'mirror_group'}
          ->{$current_mirror_group};

        foreach my $pd ( @{$current_mirror_group_list} ) {
          next LINE if ( $pd eq $1 );
        }
        push @{$current_mirror_group_list}, $1;
      }
      next;
    }

    if (  defined($current_array)
      and defined($current_logical_drive) )
    {
      if ( my ( $k, $v ) = &K_V($line) ) {
        next unless defined($k);
        $controller->{$current_controller}->{'array'}->{$current_array}
          ->{'logical_drive'}->{$current_logical_drive}->{$k} = $v;
      }
      next;
    }

    if (  defined($current_array)
      and defined($current_physical_drive) )
    {
      if ( my ( $k, $v ) = &K_V($line) ) {
        next unless defined($k);
        if ( $current_array eq 'unassigned' ) {
          $controller->{$current_controller}->{'unassigned'}
            ->{'physical_drive'}->{$current_physical_drive}->{$k} = $v;
        }
        else {
          $controller->{$current_controller}->{'array'}->{$current_array}
            ->{'physical_drive'}->{$current_physical_drive}->{$k} = $v;
        }
      }
      next;
    }

    if ( defined($current_array) ) {
      if ( my ( $k, $v ) = &K_V($line) ) {
        next unless defined($k);
        $controller->{$current_controller}->{'array'}->{$current_array}->{$k} =
          $v;
      }
      next;
    }

    if ( my ( $k, $v ) = &K_V($line) ) {
      next unless defined($k);
      $controller->{$current_controller}->{$k} = $v;
    }
    next;
  }

  return $controller;
}

sub K {
  my ($k) = @_;

  $k = lc $k;
  $k =~ s/[ \/\-]/_/g;
  $k =~ s/[\(\)]//g;

  return $k;
}

sub V {
  my ( $k, $v ) = @_;

  if ( $k eq 'accelerator_ratio' ) {
    if ( $v =~ /([0-9]+)% Read \/ ([0-9]+)% Write/ ) {
      return { 'read' => $1, 'write' => $2 };
    }
  }

  return $v;
}

sub K_V {
  my ($line) = @_;

  if ( $line =~ /(.+):\s+(.+)/ ) {
    my $k = &K($1);
    my $v = &V( $k, $2 );
    return ( $k, $v );
  }

  return ( undef, undef );
}

1;
