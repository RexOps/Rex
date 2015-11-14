use Test::More tests => 2;
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
