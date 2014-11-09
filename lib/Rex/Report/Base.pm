#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Report::Base;

use warnings;

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
  $self->{__current_resource__} = "";

  return $self;
}

sub report {
  my ( $self, %option ) = @_;

  confess "not inside a resource." if ( !$self->{__current_resource__} );

  if ( $option{changed} && !exists $option{message} ) {
    $option{message} = "Resource updated.";
  }
  elsif ( $option{changed} == 0 && !exists $option{message} ) {
    $option{message} = "Resource already up-to-date.";
  }

  #  push @{$self->{__reports__}}, $msg;
  $self->{__reports__}->{ $self->{__current_resource__} }->{changed} =
    $option{changed} || 0;

  push @{ $self->{__reports__}->{ $self->{__current_resource__} }->{messages} },
    $option{message};
}

sub report_task_execution {
  my ( $self, %option ) = @_;
  $self->{__reports__}->{task} = \%option;
}

sub report_resource_start {
  my ( $self, %option ) = @_;

  if ( $self->{__current_resource__} ) {
    Rex::Logger::debug("Another resource is in progress.");
    return;
  }

  if ( exists $self->{__reports__}->{ $self->{__current_resource__} } ) {
    Rex::Logger::debug(
      "Multiple definitions of the same resource found. ($self->{__current_resource__})",
    );
  }

  $self->{__current_resource__} = $self->_gen_res_name(%option);
  $self->{__reports__}->{ $self->{__current_resource__} } = {
    changed    => 0,
    messages   => [],
    start_time => time,
  };
}

sub report_resource_end {
  my ( $self, %option ) = @_;

  confess "not inside a resource." if ( !$self->{__current_resource__} );
  if ( $self->_gen_res_name(%option) ne $self->{__current_resource__} ) {
    Rex::Logger::debug("Another resource is in progress");
    return;
  }

  $self->{__reports__}->{ $self->{__current_resource__} }->{end_time} = time;
  $self->{__current_resource__} = "";
}

sub report_resource_failed {
  my ( $self, %opt ) = @_;
  $self->{__reports__}->{ $self->{__current_resource__} }->{failed} = 1;
  push @{ $self->{__reports__}->{ $self->{__current_resource__} }->{messages} },
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
