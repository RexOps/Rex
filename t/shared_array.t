use strict;
use warnings;

BEGIN {
  use Test::More tests => 11;
  use Test::Deep;
  use Rex::Shared::Var;
  share('@array');
}

is( shift @array, undef, "shift from empty shared array" );
is( pop @array,   undef, "pop from empty shared array" );

@array = qw(one two three four);
is( join( "-", @array ), "one-two-three-four", "array test" );

push( @array, "five" );
is( $array[-1], "five", "array push" );

is( shift @array, "one", "shift from shared array" );
is_deeply( \@array, [qw(two three four five)], "shared array after shift" );

is( pop @array, "five", "pop from shared array" );
is_deeply( \@array, [qw(two three four)], "shared array after pop" );

unshift( @array, "six" );
is( $array[0], "six", "unshift to shared array" );

push( @array, qw(seven eight) );
is_deeply( [ @array[ -2, -1 ] ],
  [qw(seven eight)], "push list to shared array" );

unshift( @array, qw(nine ten) );
is_deeply( [ @array[ 0, 1 ] ], [qw(nine ten)], "unshift list to shared array" );
