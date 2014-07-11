use strict;
use warnings;

use Test::More tests => 13;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';
use_ok 'Rex::Group::Entry::Server';
use_ok 'Rex::Commands::Virtualization';

Rex::Commands->import();

desc("Test");
task(
  "test",
  sub {
    return "test";
  }
);

ok( 1 == Rex::TaskList->create()->is_task("test"), "is_task" );
ok( "Test" eq Rex::TaskList->create()->get_desc("test"),
  "get test task description" );
ok( "test" eq Rex::TaskList->create()->get_task("test")->run("<local>"),
  "run test task" );

1;

