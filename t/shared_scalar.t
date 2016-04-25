use strict;
use warnings;

BEGIN {
  use Test::More tests => 1;
  use Rex::Shared::Var;
  share('$scalar');
}

$scalar = "scalar";
is( $scalar, "scalar", "scalar test" );
