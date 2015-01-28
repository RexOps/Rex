package main;

use Test::More;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';

Rex::Commands->import();

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

done_testing();
