#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::TaskList::Parallel_ForkManager;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

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

sub run {
  my ( $self, $task, %options ) = @_;

  if ( !ref $task ) {
    $task = Rex::TaskList->create()->get_task($task);
  }

  my $fm = Parallel::ForkManager->new( $self->get_thread_count($task) );
  $fm->set_waitpid_blocking_sleep(
    Rex::Config->get_waitpid_blocking_sleep_time );
  my $all_servers = $task->server;

  $fm->run_on_finish(
    sub {
      my ( $pid, $exit_code ) = @_;
      Rex::Logger::debug("Fork exited: $pid -> $exit_code");
    }
  );

  for my $server (@$all_servers) {
    my $child_coderef = $self->build_child_coderef( $task, $server, %options );

    if ( $self->{IN_TRANSACTION} ) {

      # Inside a transaction -- no forking and no chance to get zombies.
      # This only happens if someone calls do_task() from inside a transaction.
      $child_coderef->();
    }
    else {
      # Not inside a transaction, so lets fork
      $fm->start and next;
      $child_coderef->();
      $fm->finish;
    }
  }

  Rex::Logger::debug("Waiting for children to finish");
  my $ret = $fm->wait_all_children;
  Rex::reconnect_lost_connections();

  return $ret;
}

1;
