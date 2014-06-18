#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Base;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Logger;

my $known_services = {};

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{__cmd_output__} = '';

  return $self;
}

sub get_output            { shift->{__cmd_output__}; }
sub _prepare_service_name { return $_[1]; }

sub _filter_options {
  my ( $self, $service, $options ) = @_;

  for my $key (qw/start stop status restart reload ensure_stop ensure_start/) {
    if ( exists $options->{$key} ) {
      $known_services->{$service}->{$key} = $options->{$key};
    }
  }
}

sub _execute {
  my ( $self, $cmd ) = @_;

  $self->{__cmd_output__} = i_run $cmd, nohup => 1;

  if ( $? == 0 ) {
    return 1;
  }

  return 0;
}

sub start {
  my ( $self, $service, $options ) = @_;
  $service = $self->_prepare_service_name($service);
  $self->_filter_options( $service, $options );

  my $cmd = sprintf $self->{commands}->{start}, $service;

  if ( exists $known_services->{$service}->{start} ) {
    $cmd = $known_services->{$service}->{start};
  }

  return $self->_execute($cmd);
}

sub restart {
  my ( $self, $service, $options ) = @_;
  $service = $self->_prepare_service_name($service);
  $self->_filter_options( $service, $options );

  my $cmd = sprintf $self->{commands}->{restart}, $service;

  if ( exists $known_services->{$service}->{restart} ) {
    $cmd = $known_services->{$service}->{restart};
  }

  return $self->_execute($cmd);
}

sub stop {
  my ( $self, $service, $options ) = @_;
  $service = $self->_prepare_service_name($service);
  $self->_filter_options( $service, $options );

  my $cmd = sprintf $self->{commands}->{stop}, $service;

  if ( exists $known_services->{$service}->{stop} ) {
    $cmd = $known_services->{$service}->{stop};
  }

  return $self->_execute($cmd);
}

sub reload {
  my ( $self, $service, $options ) = @_;
  $service = $self->_prepare_service_name($service);
  $self->_filter_options( $service, $options );

  my $cmd = sprintf $self->{commands}->{reload}, $service;

  if ( exists $known_services->{$service}->{reload} ) {
    $cmd = $known_services->{$service}->{reload};
  }

  return $self->_execute($cmd);
}

sub status {
  my ( $self, $service, $options ) = @_;
  $service = $self->_prepare_service_name($service);
  $self->_filter_options( $service, $options );

  my $cmd = sprintf $self->{commands}->{status}, $service;

  if ( exists $known_services->{$service}->{status} ) {
    $cmd = $known_services->{$service}->{status};
  }

  return $self->_execute($cmd);
}

sub ensure {
  my ( $self, $service, $options ) = @_;
  $service = $self->_prepare_service_name($service);
  $self->_filter_options( $service, $options );

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    my $cmd = sprintf $self->{commands}->{ensure_stop}, $service;

    if ( exists $known_services->{$service}->{ensure_stop} ) {
      $cmd = $known_services->{$service}->{ensure_stop};
    }

    return $self->_execute($cmd);
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    my $cmd = sprintf $self->{commands}->{ensure_start}, $service;

    if ( exists $known_services->{$service}->{ensure_start} ) {
      $cmd = $known_services->{$service}->{ensure_start};
    }

    return $self->_execute($cmd);
  }
}

sub action {
  my ( $self, $service, $action ) = @_;
  $service = $self->_prepare_service_name($service);
  $self->_filter_options( $service, $options );

  my $cmd = sprintf $self->{commands}->{action}, $service, $action;
  return $self->_execute($cmd);
}

1;
