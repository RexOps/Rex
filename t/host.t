package main;

use Test::More tests => 13;

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
task("test", "server01", "server02", sub {

});

desc("Test 2");
task("test2", "fe[01..10]", sub {


});

desc("Test 3");
task("test3", "fe06", "server02", sub {


});



my @tasks = Rex::TaskList->create()->get_tasks_for("server01");
ok($tasks[0] eq "test");
ok(scalar(@tasks) == 1);

@tasks = Rex::TaskList->create()->get_tasks_for("fe06");
ok($tasks[0] eq "test2");
ok($tasks[1] eq "test3");
ok(scalar(@tasks) == 2);


1;

