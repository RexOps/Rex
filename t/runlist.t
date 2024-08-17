#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Warnings qw(:no_end_test had_no_warnings);

use Rex::Args;
use Rex::RunList;
use Rex::Commands;

$Rex::Logger::silent = 1;
Rex::Config->set_task_chaining_cmdline_args(1);

task task1 => sub { };
task task2 => sub { };
task task3 => sub { };
task task4 => sub { };

@ARGV = qw(task1 arg1 arg2 --name=thename --num=5 task2 arg task3 --hey=what);

my $run_list = Rex::RunList->instance;
$run_list->parse_opts(@ARGV);

my @tasks = $run_list->tasks;

is scalar @tasks, 3,           "run list has 3 tasks";
is ref $_,        'Rex::Task', "object isa Rex::Task" for @tasks;

note "opts";
is_deeply { $tasks[0]->get_opts }, { name => 'thename', num => 5 },
  "task0 opts";
is_deeply { $tasks[1]->get_opts }, {}, "task1 opts";
is_deeply { $tasks[2]->get_opts }, { hey => 'what' }, "task2 opts";

note "args";
is_deeply [ $tasks[0]->get_args ], [qw/arg1 arg2/], "task0 args";
is_deeply [ $tasks[1]->get_args ], [qw/arg/],       "task1 args";
is_deeply [ $tasks[2]->get_args ], [qw//],          "task2 args";

$run_list->run_tasks;

had_no_warnings;
done_testing;
