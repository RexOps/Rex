#!/usr/bin/env perl

use v5.12.5;
use warnings;
use lib 't/lib';

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Warnings;
use Test::Deep;

use Rex::Commands;
use Rex::Commands::Run;

use t::tasks::cowbefore;

$::QUIET = 1;

my $task_list = Rex::TaskList->create;

my @task_names = $task_list->get_tasks;
cmp_deeply
  \@task_names,
  [qw/t:tasks:cowbefore:roundup/],
  "found task";

for my $tn (@task_names) {
  my $before = $task_list->get_task($tn)->get_data->{before};
  ok($before);
  is( ( scalar @$before ), 1,    $tn );
  is( $before->[0]->(),    'yo', $tn ) if (@$before);
}

done_testing();
