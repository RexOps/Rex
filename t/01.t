#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';

Rex::Commands->import();

desc("Test");
task("test", sub {
	return "test";
});

ok(1 == Rex::Task->is_task("test"), "is_task");
ok("Test" eq Rex::Task->get_desc("test"), "get test task description");
ok("test" eq Rex::Task->run("test"), "run test task");

1;

