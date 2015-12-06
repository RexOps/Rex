use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 2;
use Test::Deep;

use Rex::Commands;
use Rex::Commands::Run;

use t::tasks::cowboy;

$::QUIET = 1;

my $task_list = Rex::TaskList->create;

my @task_names = $task_list->get_tasks;
cmp_deeply
  \@task_names,
  [qw/t:tasks:cowboy:roundup/],
  "found visible task";

my @all_task_names = sort $task_list->get_all_tasks(qr/.*/);
cmp_deeply
  \@all_task_names,
  [qw/t:tasks:alien:negotiate t:tasks:cowboy:roundup/],
  "found hidden task";

done_testing();
