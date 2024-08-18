#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use English qw(-no_match_vars);

use Test::More;
use if $OSNAME ne 'MSWin32' || $PERL_VERSION gt 'v5.20.0', 'Test::Warnings';
use Test::Deep;

use Module::Load::Conditional qw(check_install);
use Rex::Config;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Transaction;

$::QUIET = 1;

my @distributors = ('Base');

if ( check_install( module => 'Parallel::ForkManager' ) ) {
  push @distributors, 'Parallel_ForkManager';
}

my $extra_test_count = defined $Test::Warnings::VERSION ? 1 : 0;

plan tests => scalar @distributors * 2 + $extra_test_count;

for my $distributor (@distributors) {

  Rex::Config->set_distributor($distributor);

  subtest "$distributor distributor with exec_autodie => 0" => sub {
    Rex::Config->set_exec_autodie(0);
    test_summary(
      task0 => { server => '<local>', task => 'task0', exit_code => 1 },
      task1 => { server => '<local>', task => 'task1', exit_code => 0 },
      task2 => { server => '<local>', task => 'task2', exit_code => 0 },
      task3 => { server => '<local>', task => 'task3', exit_code => 1 },
    );
  };

  subtest "$distributor distributor with exec_autodie => 1" => sub {
    Rex::Config->set_exec_autodie(1);
    test_summary(
      task0 => { server => '<local>', task => 'task0', exit_code => 1 },
      task1 => { server => '<local>', task => 'task1', exit_code => 1 },
      task2 => { server => '<local>', task => 'task2', exit_code => 0 },
      task3 => { server => '<local>', task => 'task3', exit_code => 1 },
    );
  };
}

sub create_tasks {
  desc "desc 0";
  task "task0" => sub {
    die "bork0";
  };

  desc "desc 1";
  task "task1" => sub {
    my $cmd = $^O =~ /MSWin32/ ? "type" : "cat";
    run "$cmd asdfxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
  };

  desc "desc 2";
  task "task2" => sub {
    my $cmd = $^O =~ /MSWin32/ ? "dir" : "ls";
    run $cmd;
  };

  desc "desc 3";
  task "task3" => sub {
    transaction {
      do_task qw/task0/;
    };
  };
}

sub test_summary {
  my (%expected) = @_;
  my @expected_summary;

  $Rex::TaskList::task_list = undef;

  create_tasks();

  for my $task_name ( Rex::TaskList->create->get_tasks ) {
    Rex::TaskList->run($task_name);
    my @summary = Rex::TaskList->create->get_summary;

    # for the tests we remove the error message.
    for (@summary) {
      delete $_->{error_message};
    }

    push @expected_summary, $expected{$task_name};

    my $test_description =
      $expected{$task_name}->{exit_code} == 0
      ? "$task_name succeeded"
      : "$task_name failed";

    cmp_deeply \@summary, \@expected_summary, $test_description;
  }

  my $distributor = Rex::Config->get_distributor;
  no warnings;

  @Rex::TaskList::Base::SUMMARY = ();
}
