#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 3;
use Test::Warnings;

use Rex -base;

is( Rex::Config->get_waitpid_blocking_sleep_time, 0.1, 'default is set' );

Rex::Config->set_waitpid_blocking_sleep_time(1);
is( Rex::Config->get_waitpid_blocking_sleep_time,
  1, 'waitpid blocking sleep time is set' );
