use strict;
use warnings;

use Test::More tests => 2;

use Rex -base;

is( Rex::Config->get_waitpid_blocking_sleep_time, 0.1, 'default is set' );

Rex::Config->set_waitpid_blocking_sleep_time(1);
is( Rex::Config->get_waitpid_blocking_sleep_time,
  1, 'waitpid blocking sleep time is set' );
