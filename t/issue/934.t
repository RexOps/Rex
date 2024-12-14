#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 2;
use Test::Warnings qw(:no_end_test had_no_warnings);

use Rex::Args;
use Rex::RunList;
use Rex::Commands;
use Rex::CLI;
use Rex::Transaction;
use Rex::Args;

BEGIN {
  use Rex::Shared::Var;
  share qw(%opt_t1 %opt_t2 %opt_t3);
}

$::QUIET = 1;

$::rexfile = "noop";

task task1 => sub {

};

before_task_start task1 => sub {
  my %args = Rex::Args->get;
  is( $args{name}, "thename", "got taskopt" );
};

@ARGV = qw(task1 --name=thename --num=5 --hey=what);

my $run_list = Rex::RunList->instance;
$run_list->parse_opts(@ARGV);
$run_list->run_tasks;

had_no_warnings();
