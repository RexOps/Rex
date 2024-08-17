#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 8;
use Test::Warnings;
use Rex::Commands;

my $test = "Debian";

my $var = case $test, {
  Debian    => "foo",
    default => "bar",
};

is( $var, "foo", "string equality" );

$var = case $test, {
  qr{debian}i => "baz",
    default   => "this is bad",
};

is( $var, "baz", "regexp match" );

$var = case $test, {
  debian    => "some",
    default => "this is good",
};

is( $var, "this is good", "return default" );

$var = case $test, {
  debian => "tata",
};

ok( !$var, "var is undef" );

$var = case $test, {
  Debian    => sub { return "this is debian"; },
    default => sub { return "default"; }
};

is( $var, "this is debian", "use a sub - string match" );

$var = undef;

$var = case $test, {
  qr{debian}i => sub { return "this is debian"; },
    default   => sub { return "default"; }
};

is( $var, "this is debian", "use a sub - regexp match" );

$var = undef;

$var = case $test, {
  debian    => sub { return "this is debian"; },
    default => sub { return "default"; }
};

is( $var, "default", "use a sub - return default" );
