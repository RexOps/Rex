use strict;
use warnings;

BEGIN {
  use Test::More tests => 5;
  use Rex::Shared::Var;
  share('%hash');
}

%hash = (
  name     => "joe",
  surename => "doe",
  multi    => {
    key1 => "foo",
    arr1 => [qw/bar baz/],
  }
);

is( $hash{name},               "joe", "hash test, key 1" );
is( $hash{surename},           "doe", "hash test, key 2" );
is( $hash{multi}->{key1},      "foo", "multidimension, key1" );
is( $hash{multi}->{arr1}->[0], "bar", "multidimension, arr1 - key0" );
is( $hash{multi}->{arr1}->[1], "baz", "multidimension, arr1 - key1" );
