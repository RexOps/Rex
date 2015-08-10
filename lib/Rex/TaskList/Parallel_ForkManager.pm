#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::TaskList::Parallel_ForkManager;

use strict;
use warnings;

# VERSION

use Data::Dumper;
use Rex::Logger;
use Rex::Task;
use Rex::Config;
use Rex::Interface::Executor;
use Rex::TaskList::Base;
use Rex::Report;
use Time::HiRes qw(time);

BEGIN {
  use Rex::Require;
  Parallel::ForkManager->require;
}

use base qw(Rex::TaskList::Base);

my @PROCESS_LIST;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub run {
  my ( $self, $task_names, %option ) = @_;

  $option{params} ||= { Rex::Args->get };

  my @tasks = $self->get_tasks(@$task_names);
  my $fm    = Rex::Fork::Manager->new(
    max => $self->get_thread_count($tasks[0])
  );

  $fm->run_on_finish(
    sub {
      my ( $pid, $exit_code ) = @_;
      Rex::Logger::debug("Fork exited: $pid -> $exit_code");
      push @PROCESS_LIST, $exit_code;
    }
  );

  my @servers = @{ $task->server };

  for my $server (@servers) {

    my $forked_sub = sub {
      Rex::Logger::init();

      for my $task (@tasks) {
        my $task_name = $task->name;
        Rex::Logger::info("Running task $task_name on $server");

        my $run_task = Rex::Task->new( %{ $task->get_data } );

        $run_task->run(
          $server,
          in_transaction => $self->{IN_TRANSACTION},
          params         => $option{params}
        );
      }

      Rex::Logger::debug("Destroying all cached os information");
      Rex::Logger::shutdown();
    };

    # add the worker (forked_sub) to the fork queue
    unless ( $self->{IN_TRANSACTION} ) {

      # not inside a transaction, so lets fork happyly...
      $fm->start and next;
      eval {
        $forked_sub->();
        1;
      } or do {

        # exit with error
        $? = 255 if !$?; # unknown error
        exit $?;
      };
      $fm->finish;
    }
    else {
# inside a transaction, no little small funny kids, ... and no chance to get zombies :(
      &$forked_sub();
    }

  }

  Rex::Logger::debug("Waiting for children to finish");
  my $ret = $fm->wait_all_children;

  Rex::reconnect_lost_connections();

  return $ret;
}

sub get_exit_codes {
  my ($self) = @_;
  return @PROCESS_LIST;
}

1;
