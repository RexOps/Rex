#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::CLI;

use Test::More tests => 3;
use Test::Warnings;

my $ok = 0;

eval {
  Rex::CLI::load_rexfile("t/issue/513_t1.rex");
  $ok = 1;
};

is( $ok, 1, "Rexfile with false return value was loaded successfull." );

$ok = 0;

eval {
  Rex::CLI::load_rexfile("t/issue/513_t2.rex");
  $ok = 1;
};

is( $ok, 1, "Rexfile with true return value was loaded successfull." );
