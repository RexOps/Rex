use strict;
use warnings;

use Rex::Commands;
use Rex::Commands::Task;

use Test::More tests => 4;

eval { Rex::Commands::Task::do_task("non_existing_task"); };
my $result = $@;

isnt( $result, undef, 'exception for do_task non-existing task' );
like(
  $result,
  qr/Task non_existing_task not found\./,
  'do_task non-existing task'
);

eval { Rex::Commands::Task::do_task( ["non_existing_task"] ); };
$result = $@;

isnt( $result, undef, 'exception for do_task non-existing task as arrayref' );
like(
  $result,
  qr/Task non_existing_task not found\./,
  'do_task non-existing task as arrayref'
);
