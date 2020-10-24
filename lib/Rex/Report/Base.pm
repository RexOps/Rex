#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Report::Base;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;
use Rex::Logger;
use Time::HiRes qw(time);
use Carp;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{__reports__}          = {};
  $self->{__current_resource__} = [];

  return $self;
}

sub report {
  my ( $self, %option ) = @_;

  confess "not inside a resource." if ( !$self->{__current_resource__}->[-1] );

  if ( $option{changed} && !exists $option{message} ) {
    $option{message} = "Resource updated.";
  }
  elsif ( $option{changed} == 0 && !exists $option{message} ) {
    $option{message} = "Resource already up-to-date.";
  }

  # update all stacked resources
  for my $res ( @{ $self->{__current_resource__} } ) {
    $self->{__reports__}->{$res}->{changed} ||= $option{changed} || 0;
  }

  push
    @{ $self->{__reports__}->{ $self->{__current_resource__}->[-1] }->{messages}
    },
    $option{message};
}

sub report_task_execution {
  my ( $self, %option ) = @_;
  $self->{__reports__}->{task} = \%option;
}

sub report_resource_start {
  my ( $self, %option ) = @_;

  push @{ $self->{__current_resource__} }, $self->_gen_res_name(%option);
  $self->{__reports__}->{ $self->{__current_resource__}->[-1] } = {
    changed    => 0,
    messages   => [],
    start_time => time,
  };
}

sub report_resource_end {
  my ( $self, %option ) = @_;

  confess "not inside a resource." if ( !$self->{__current_resource__}->[-1] );

  $self->{__reports__}->{ $self->{__current_resource__}->[-1] }->{end_time} =
    time;
  pop @{ $self->{__current_resource__} };
}

sub report_resource_failed {
  my ( $self, %opt ) = @_;

  return if ( !$self->{__current_resource__}->[-1] );

  # update all stacked resources
  for my $res ( @{ $self->{__current_resource__} } ) {
    $self->{__reports__}->{$res}->{failed} = 1;
  }

  push @{ $self->{__reports__}->{ $self->{__current_resource__} > [-1] }
      ->{messages} },
    $opt{message};
}

sub write_report {
  my ($self) = @_;
}

sub _gen_res_name {
  my ( $self, %option ) = @_;
  return $option{type} . "[" . $option{name} . "]";
}

1;
