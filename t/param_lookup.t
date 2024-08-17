#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

package main;

use Test::More tests => 9;
use Test::Warnings;
use Rex -base;
use Rex::Resource;

$::QUIET = 1;

task(
  "test1",
  sub {
    my $x  = param_lookup( "name", "foo" );
    my $tp = template( \'<%= $name %>' );

    is( $x,  "foo", "got default value" );
    is( $tp, "foo", "got default value in template" );
  }
);

task(
  "test2",
  sub {
    my $x  = param_lookup( "name", "foo" );
    my $tp = template( \'<%= $name %>' );

    is( $x,  "rex", "got parameter value" );
    is( $tp, "rex", "got parameter value in template" );
  }
);

task(
  "test3",
  sub {
    test1();

    my $x  = param_lookup( "name", "foo" );
    my $tp = template( \'<%= $name %>' );

    is( $x,  "xer", "got parameter value" );
    is( $tp, "xer", "got parameter value in template" );
  }
);

test1();
test2( { name => "rex" } );
test3( { name => "xer" } );
