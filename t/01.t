#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 4;
use Test::Warnings;

use Rex::Commands;

desc("Test");
task(
  "test",
  sub {
    return "test";
  }
);

is( 1, Rex::TaskList->create()->is_task("test"), "is_task" );
is(
  "Test",
  Rex::TaskList->create()->get_desc("test"),
  "get test task description"
);
is(
  "test",
  Rex::TaskList->create()->get_task("test")->run("<local>"),
  "run test task"
);

1;
