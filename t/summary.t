use strict;
use warnings;

use Test::More tests => 2;
use Test::Deep;

use Rex::Config;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Transaction;

$::QUIET = 1;

subtest "distributor => 'Base'" => sub {

  subtest 'exec_autodie => 0' => sub {
    Rex::Config->set_exec_autodie(0);
    Rex::Config->set_distributor('Base');
    test_summary(
      task0 => { server => '<local>', task => 'task0', exit_code => 1 },
      task1 => { server => '<local>', task => 'task1', exit_code => 0 },
      task2 => { server => '<local>', task => 'task2', exit_code => 0 },
      task3 => { server => '<local>', task => 'task3', exit_code => 1 },
      task4 => { server => '<local>', task => 'task4', exit_code => 1 },
    );
  };

  subtest 'exec_autodie => 1' => sub {
    Rex::Config->set_exec_autodie(1);
    Rex::Config->set_distributor('Base');
    test_summary(
      task0 => { server => '<local>', task => 'task0', exit_code => 1 },
      task1 => { server => '<local>', task => 'task1', exit_code => 2 },
      task2 => { server => '<local>', task => 'task2', exit_code => 0 },
      task3 => { server => '<local>', task => 'task3', exit_code => 1 },
      task4 => { server => '<local>', task => 'task4', exit_code => 1 },
    );
  };
};

SKIP: {
  skip "Parallel::ForkManager is not installed", 1
    if parallel_forkmanager_not_installed();

  subtest "distributor => 'Parallel_ForkManager'" => sub {
    subtest 'exec_autodie => 0' => sub {
      Rex::Config->set_exec_autodie(0);
      Rex::Config->set_distributor('Parallel_ForkManager');
      test_summary(
        task0 => { server => '<local>', task => 'task0', exit_code => 1 },
        task1 => { server => '<local>', task => 'task1', exit_code => 0 },
        task2 => { server => '<local>', task => 'task2', exit_code => 0 },
        task3 => { server => '<local>', task => 'task3', exit_code => 1 },
        task4 => { server => '<local>', task => 'task4', exit_code => 1 },
      );
    };

    subtest 'exec_autodie => 1' => sub {
      Rex::Config->set_exec_autodie(1);
      Rex::Config->set_distributor('Parallel_ForkManager');
      test_summary(
        task0 => { server => '<local>', task => 'task0', exit_code => 1 },
        task1 => { server => '<local>', task => 'task1', exit_code => 2 },
        task2 => { server => '<local>', task => 'task2', exit_code => 0 },
        task3 => { server => '<local>', task => 'task3', exit_code => 1 },
        task4 => { server => '<local>', task => 'task4', exit_code => 1 },
      );
    };
  };
}

sub create_tasks {
  desc "desc 0";
  task "task0" => sub {
    die "bork0";
  };

  desc "desc 1";
  task "task1" => sub {
    my $cmd = $^O =~ /MSWin32/ ? "dir" : "ls";
    run "$cmd asdfxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
  };

  desc "desc 2";
  task "task2" => sub {
    my $cmd = $^O =~ /MSWin32/ ? "dir" : "ls";
    run $cmd;
  };

  desc "desc 3"; # test do_task() in a transaction
  task "task3" => sub {
    transaction { do_task qw/task0/ };
  };

  desc "desc 4"; # test do_task()
  task "task4" => sub {
    do_task qw/task0/;
  };
}

sub test_summary {
  my (%expected) = @_;

  $Rex::TaskList::task_list = undef;

  create_tasks();

  my @summary;
  my @expected_summary;
  my $test_description;

  for my $task_name ( Rex::TaskList->create->get_tasks ) {
    Rex::TaskList->run($task_name);
    @summary = Rex::TaskList->create->get_summary;

    push @expected_summary, $expected{$task_name};

    $test_description =
      $expected{$task_name}->{exit_code} == 0
      ? "$task_name succeeded"
      : "$task_name failed";

    cmp_deeply \@summary, \@expected_summary, $test_description;
  }

  my $distributor = Rex::Config->get_distributor;
  no warnings;

  @Rex::Fork::Task::SUMMARY = ()
    if $distributor eq 'Base';

  @Rex::TaskList::Parallel_ForkManager::SUMMARY = ()
    if $distributor eq 'Parallel_ForkManager';
}

sub parallel_forkmanager_not_installed {
  eval { require Parallel::ForkManager };
  return 1 if $@;
  return 0;
}
