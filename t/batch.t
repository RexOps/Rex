#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 3;
use Test::Warnings;
use Rex::Commands;
use Rex::Batch;

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

batch( "mybatch", "test", "test2" );

my @batches    = Rex::Batch->get_batchs();
my @task_names = Rex::Batch->get_batch("mybatch");

is_deeply( \@batches, ["mybatch"], "Batch 'mybatch' registered successfully." );
is_deeply( \@task_names, [ "test", "test2" ],
  "Batch 'mybatch' has all tasks." );
