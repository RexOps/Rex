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
    return $self->execute_resource_code('present');
  }
}

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
  if(exists $self->config->{timeout}) {
    my $ret = timeout $self->config->{timeout}, sub {
      return $self->$code;
    };

    if($ret && ref $ret eq "HASH") {
      $return_data = $ret;
    }
    else {
      $return_data = {
        value => $@,
        exit_code => $?,
        changed => 0,
      };
    }
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

1;
