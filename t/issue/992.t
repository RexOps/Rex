use strict;
use warnings;

use Test::More tests => 1;

use Rex::Commands;
use Rex::Commands::Task;

eval {
  do_task "non_existing_task";
  1;
} or do {
  like $@, qr/^Task non_existing_task not found\./,
    "Error message for unknown task is okay.";
};

