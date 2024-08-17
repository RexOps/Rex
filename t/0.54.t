#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 14;
use Test::Warnings;

use Rex -feature => '0.54';

set( "key1", "val1" );
is( get("key1"), "val1", "got value of key1" );

set( "key1", "val2" );
is( get("key1"), "val2", "got new value of key1" );

set( "key2", [qw/one two three/] );
is( get("key2")->[0], "one",   "got value of first item in key2" );
is( get("key2")->[1], "two",   "got value of 2nd item in key2" );
is( get("key2")->[2], "three", "got value of 3rd item in key2" );

set( "key2", [qw/four five/] );
is( get("key2")->[0], "four", "got value of NEW first item in key2" );
is( get("key2")->[1], "five", "got value of NEW 2nd item in key2" );

set( "key3", { name => 'foo', surname => 'bar' } );
is( get("key3")->{name},    "foo", "got value of name parameter in key3" );
is( get("key3")->{surname}, "bar", "got value of surname parameter in key3" );

set( "key3", { x1 => 'x', x2 => 'xx' } );
is( get("key3")->{x1}, "x",  "got value of NEW name parameter x1 in key3" );
is( get("key3")->{x2}, "xx", "got value of NEW name parameter x2 in key3" );
ok( !exists get("key3")->{name}, "name parameter doesn't exists anymore" );
ok( !exists get("key3")->{surname},
  "surname parameter doesn't exists anymore" );
