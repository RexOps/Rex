use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;

use Rex::Commands;
use Rex::Commands::Run;

use t::tasks::chicken;

$::QUIET = 1;

my $task_list = Rex::TaskList->create;

my ($task_name) = $task_list->get_tasks;
is( $task_name, "t:tasks:chicken:cross_road", "found_task" );
my $task = $task_list->get_task($task_name);

my $bts = $task->{before_task_start};

is( @$bts, 2, "found 2 before_task_start hooks" );
is( ref $bts->[0] eq "CODE" ? $bts->[0]->() : undef,
  "look left", "first before_task_start hook executes" );
is( ref $bts->[1] eq "CODE" ? $bts->[1]->() : undef,
  "look right", "second before_task_start hook executes" );

my $atf = $task->{after_task_finished};

is( @$atf, 2, "found 2 after_task_finished hooks" );
is(
  ref $atf->[0] eq "CODE" ? $atf->[0]->() : undef,
  "got to the other side",
  "first after_task_finished hook executes"
);
is( ref $atf->[1] eq "CODE" ? $atf->[1]->() : undef,
  "celebrate!", "second after_task_finished hook executes" );

done_testing();
