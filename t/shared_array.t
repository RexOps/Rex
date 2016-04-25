use strict;
use warnings;

BEGIN {
  use Test::More tests => 22;
  use Test::Deep;
  use Rex::Shared::Var;
  share('@array');
}

is( scalar @array, 0,     "empty array size" );
is( shift @array,  undef, "shift from empty shared array" );
is( pop @array,    undef, "pop from empty shared array" );

$#array = 1;
is( scalar @array, 2, "array size after expanding" );

$#array = 0;
is( scalar @array, 1, "array size after shrinking" );

@array = qw(one two three four);
is( scalar @array, 4, "array size after assignment" );
is( join( "-", @array ), "one-two-three-four", "array test" );

push( @array, "five" );
is( scalar @array, 5,      "array size after push" );
is( $array[-1],    "five", "array push" );

is( shift @array,  "one", "shift from shared array" );
is( scalar @array, 4,     "array size after shift" );
is_deeply( \@array, [qw(two three four five)], "shared array after shift" );

is( pop @array,    "five", "pop from shared array" );
is( scalar @array, 3,      "array size after pop" );
is_deeply( \@array, [qw(two three four)], "shared array after pop" );

unshift( @array, "six" );
is( scalar @array, 4,     "array size after unshift" );
is( $array[0],     "six", "unshift to shared array" );

push( @array, qw(seven eight) );
is( scalar @array, 6, "array size after push list" );
is_deeply( [ @array[ -2, -1 ] ],
  [qw(seven eight)], "push list to shared array" );

unshift( @array, qw(nine ten) );
is( scalar @array, 8, "array size after unshift list" );
is_deeply( [ @array[ 0, 1 ] ], [qw(nine ten)], "unshift list to shared array" );

@array = ();
is( scalar @array, 0, "array size after clear" );
