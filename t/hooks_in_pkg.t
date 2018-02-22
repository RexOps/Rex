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

my @task_names = $task_list->get_tasks;
cmp_deeply
  \@task_names,
  [qw/t:tasks:chicken:cross_road/],
  "found task";

for my $tn (@task_names) {
  require Data::Dumper;
  Data::Dumper->import;
  diag(Dumper($task_list->get_task($tn)->get_data));
  my $before_task_start =
    $task_list->get_task($tn)->get_data->{before_task_start};
  is( ( scalar @$before_task_start ), 1, $tn );
  is( $before_task_start->[0]->(), 'checked for traffic', $tn )
    if (@$before_task_start);
}

done_testing();
