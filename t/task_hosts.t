#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

package main;

use Test::More tests => 3;
use Test::Warnings;

use Rex::Commands;

desc("Test");
task(
  "test",
  "server01",
  "server02",
  sub {

  }
);

desc("Test 2");
task(
  "test2",
  "fe[01..10]",
  sub {

  }
);

desc("Test 3");
task(
  "test3", "fe06",
  "server02",
  sub {

  }
);

my @tasks = Rex::TaskList->create()->get_tasks_for("server01");
is_deeply( \@tasks, ["test"], "tasks has one element: 'test'" );

@tasks = Rex::TaskList->create()->get_tasks_for("fe06");
is_deeply(
  \@tasks,
  [ "test2", "test3" ],
  "tasks has two elements: 'test2' and 'test3'"
);
