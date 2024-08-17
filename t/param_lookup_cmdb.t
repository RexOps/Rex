#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -base;
use Rex::Resource;
use Test::More;
use Test::Warnings;

use Rex::CMDB;
use Rex::Commands;

$::QUIET = 1;

set(
  cmdb => {
    type => "YAML",
    path => "t/cmdb",
  }
);

use Test::More tests => 2;
use Rex -base;

task(
  "test1",
  sub {
    my $x = param_lookup( "name", "foo" );
    is( $x, "defaultname", "got default value" );
  }
);

test1();
