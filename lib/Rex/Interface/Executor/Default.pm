#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Executor::Default;

use strict;
use warnings;

# VERSION

use Rex::Hook;
use Rex::Logger;
use Data::Dumper;

use Rex::Interface::Executor::Base;

require Rex::Args;

use Moose;
extends qw(Rex::Interface::Executor::Base);

sub exec {
  my ( $self, $opts, $args ) = @_;

  my $task = $self->task;

  Rex::Logger::debug( "Executing " . $task->name );

  my $wantarray = wantarray;

  my @ret;
  eval {
    my $code = $task->code;

    my $c = Rex::Controller::Task->new( app => $self->app, params => $opts );
    $self->app->push_run_stage(
      $c,
      sub {
        Rex::Hook::run_hook( task => "before_execute", $task->name, @_ );

        if ($wantarray) {
          if ( ref $opts eq "ARRAY" ) {
            @ret = $code->( $self->app->current_run_stage );
          }
          else {
            @ret = $code->( $self->app->current_run_stage );
          }
        }
        else {
          if ( ref $opts eq "ARRAY" ) {
            $ret[0] = $code->( $self->app->current_run_stage );
          }
          else {
            $ret[0] = $code->( $self->app->current_run_stage );
          }
        }

        Rex::Hook::run_hook( task => "after_execute", $task->name, @_ );
      }
    );
  };

  my $error = $@;
  my %opts  = Rex::Args->getopts;

  if ($error) {
    if ( exists $opts{o} ) {
      Rex::Output->get->add( $task->name, error => 1, msg => $error );
    }
    else {
      Rex::Logger::info( "Error executing task:", "error" );
      Rex::Logger::info( "$error",                "error" );
      die($error);
    }
  }
  else {
    if ( exists $opts{o} ) {
      Rex::Output->get->add( $task->name );
    }
  }

  if ($wantarray) {
    return @ret;
  }
  else {
    return $ret[0];
  }
}

1;
