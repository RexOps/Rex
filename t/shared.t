use strict;
use warnings;

BEGIN {
  use Test::More tests => 9;

  use_ok 'Rex::Shared::Var';
  Rex::Shared::Var->import;

  share(qw($scalar @array %hash));
}

$scalar = "scalar";
is( $scalar, "scalar", "scalar test" );

@array = qw(one two three four);
is( join( "-", @array ), "one-two-three-four", "array test" );

push( @array, "five" );
is( $array[-1], "five", "array push" );

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

unlink("vars.db");
unlink("vars.db.lock");

