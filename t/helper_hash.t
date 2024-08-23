#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 7;
use Test::Warnings;

use Rex::Helper::Hash;

my %h = (
  name => "FooBar",
  age  => 99,
  data => {
    foo  => "bar",
    blah => "fasel",
    more => {
      a => "eins",
      b => "zwei",
      c => "drei",
      d => {
        germany => "Berlin",
        france  => "Paris",
      },
    },
    emails => [
      'm@m.m', 'a@a.a',
      {
        n1 => "nested_1",
        n2 => "nested_2",
      },
      [ 'eins', 'zwei', 'drei', ],
    ],
  },
  blub => [qw/eins zwei drei/],

);

my $nh = {};
hash_flatten( \%h, $nh, "_" );

is( $nh->{"age"},                99,      "testing flattened hash" );
is( $nh->{"data_more_d_france"}, "Paris", "testing flattened hash - nested" );
is( $nh->{"blub_0"},             "eins",  "testing flattened array" );
is( $nh->{"data_emails_0"},      'm@m.m', "testing flattened array - nested" );
is( $nh->{"data_emails_1"}, 'a@a.a', "testing flattened array - nested (2)" );
is( $nh->{"data_emails_2_n1"},
  'nested_1', "testing flattened hash nested in array" );
