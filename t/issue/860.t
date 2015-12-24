use strict;
use warnings;

use Test::More tests => 6;

use Rex::Args;
use Rex::RunList;
use Rex::Commands;
use Rex::CLI;
use Rex::Transaction;

BEGIN {
  use Rex::Shared::Var;
  share qw(%opt_t1 %opt_t2 %opt_t3);
}

$::QUIET = 1;

$::rexfile = "noop";

task task1 => sub { };
task task2 => sub { };
task task3 => sub { };

before task1 => sub {
  %opt_t1 = Rex::Args->get;
};

before task2 => sub {
  %opt_t2 = Rex::Args->get;
};

before task3 => sub {
  %opt_t3 = Rex::Args->get;
};

@ARGV = qw(task1 task2 task3 --name=thename --num=5 --hey=what);

my $run_list = Rex::RunList->instance;
$run_list->parse_opts(@ARGV);
$run_list->run_tasks;

is_deeply(
  {
    name  => "thename",
    task2 => 1,
    num   => 5,
    task1 => 1,
    hey   => "what",
    task3 => 1,
  },
  \%opt_t1,
  "got task1 parameter with pre 1.4 compatibility"
);

is_deeply(
  {
    name  => "thename",
    task2 => 1,
    num   => 5,
    task1 => 1,
    hey   => "what",
    task3 => 1,
  },
  \%opt_t2,
  "got task2 parameter with pre 1.4 compatibility"
);

is_deeply(
  {
    name  => "thename",
    task2 => 1,
    num   => 5,
    task1 => 1,
    hey   => "what",
    task3 => 1,
  },
  \%opt_t3,
  "got task3 parameter with pre 1.4 compatibility"
);

Rex::Config->set_task_chaining_cmdline_args(1);

@ARGV = qw(task1 arg1 arg2 --name=thename --num=5 task2 arg task3 --hey=what);

$run_list = Rex::RunList->instance;
$run_list->parse_opts(@ARGV);
$run_list->run_tasks;

is_deeply(
  {
    name => "thename",
    num  => 5,
  },
  \%opt_t1,
  "got task1 parameter with 1.4 compatibility"
);

is_deeply( {}, \%opt_t2, "got task2 parameter with 1.4 compatibility" );

is_deeply(
  {
    hey => "what",
  },
  \%opt_t3,
  "got task3 parameter with 1.4 compatibility"
);

