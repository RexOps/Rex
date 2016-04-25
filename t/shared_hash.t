use strict;
use warnings;

BEGIN {
  use Test::More tests => 4;
  use Test::Deep;
  use Rex::Shared::Var;
  share('%hash');
}

%hash = (
  scalar => "myscalar",
  array  => [qw(first second)],
  hash   => {
    scalar2 => "myscalar2",
    array2  => [qw(bar baz)],
  }
);

is( $hash{scalar}, "myscalar", "scalar value in shared hash" );
is_deeply( $hash{array}, [qw(first second)], "arrayref in shared hash" );
is( $hash{hash}->{scalar2}, "myscalar2", "scalar in hashref in shared hash" );
is_deeply( $hash{hash}->{array2},
  [qw(bar baz)], "arrayref in hashref in shared hash" );
