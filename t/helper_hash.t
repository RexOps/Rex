use strict;
use warnings;

use Test::More tests => 7;

use_ok 'Rex::Helper::Hash';

Rex::Helper::Hash->import;

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
  blub => [ qw/eins zwei drei/ ],

);

my $nh = {};
hash_flatten( \%h, $nh, "_" );

ok( $nh->{"age"} == 99,                     "testing flattened hash" );
ok( $nh->{"data_more_d_france"} eq "Paris", "testing flattened hash - nested" );
ok( $nh->{"blub_0"} eq "eins",              "testing flattened array" );
ok( $nh->{"data_emails_0"} eq 'm@m.m', "testing flattened array - nested" );
ok( $nh->{"data_emails_1"} eq 'a@a.a', "testing flattened array - nested (2)" );
ok(
  $nh->{"data_emails_2_n1"} eq 'nested_1',
  "testing flattened hash nested in array"
);

