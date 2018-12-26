#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Role::Testable;

use strict;
use warnings;
use Time::Out qw(timeout);

# VERSION

use Moose::Role;

requires qw(test present);

sub process {
  my ($self) = @_;

  # test if the resource is already deployed
  # only if test returns false (which means resource is not deployed) we run the resource code.
  my $res_available = $self->test;
  if ( !$res_available ) {
    my $ret = $self->execute_resource_code('present');
    return $ret;
  }
}

#
# this around() also gets called by roles that overrides
# the base process function.
around process => sub {
  my $orig = shift;
  my $self = shift;

  my $ret = $self->$orig();

  if(exists $ret->{status} && exists $ret->{changed}) {
    $self->_set_status($ret->{status});

    Rex::get_current_connection()->{reporter}->report(
      changed => $ret->{changed},
      resource => $self->type,
      name => $self->name,
      message => "Resource " . $self->type . " status changed to " . ($self->config->{ensure} || 'present') . ".",
    );
  }
  else {
    die "There is no status or changed return-proeprty for this resource: " . $self->type . "\n";
  }

  if(exists $self->config->{auto_die} && $self->config->{auto_die}) {
    if($ret->{exit_code} != 0) {
      die "Calling autodie for " . $self->type . "[" . $self->name . "]";
    }
  }

  return $ret;
};

#
# this code gets only called if the resource must be deployed.
sub execute_resource_code {
  my ($self, $code) = @_;

  my $return_data = {};

  # this new interface deprecates Rex::Hook
  #### check and run before_change hook
  # Rex::Hook::run_hook(
  #   $self->type => "before_change",
  #   $self->name, %{ $self->config }
  # );
  ##############################

  #
  # TIMEOUT:
  #
  # This code handles the timeout of a resource.
  # timeout is now a global resource option and not limited to
  # the run() resource anymore.
  if(exists $self->config->{timeout} && $self->config->{timeout} > 0) {
    $return_data = $self->_execute_timeout($code);
  }


  #
  # NO SPECIAL OPTION:
  #
  # This code handles the execution of the resource code without any
  # special options.
  else {
    $return_data = $self->$code;
  }

  #### check and run after_change hook
  # Rex::Hook::run_hook(
  #   $self->type => "after_change",
  #   $self->name, %{ $self->config }
  # );
  ##############################


  #
  # return all the gathered data
  return $return_data;
}

sub _execute_timeout {
  my ($self, $code) = @_;

    my $ret = timeout $self->config->{timeout}, sub {
      return $self->$code;
    };

    if($ret && ref $ret eq "HASH") {
      return $ret;
    }

    return {
      value => $@,
      exit_code => $?,
      changed => 0,
    };
}

1;
