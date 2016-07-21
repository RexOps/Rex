use strict;
use warnings;

BEGIN {
  use Test::More tests => 18;
  use Test::Deep;
  use Time::HiRes;
  use Rex::Shared::Var;
  share(qw($scalar @array %hash));
}

$scalar = "scalar";
is( $scalar, "scalar", "scalar test" );

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

{
  # Sleeping in a test is not ideal.  But can't replace Time::HiRes::usleep()
  # with POSIX::pause() because kill doesn't send signals on win32. See
  # 'perldoc -f kill', 'perldoc perlport' and
  # https://github.com/RexOps/Rex/pull/774

  @array = (0);
  my @pids;

  for my $i ( 0 .. 5 ) {
    my $pid = fork();
    if ( $pid == 0 ) {

      # child
      Time::HiRes::usleep 100_000; # .1 seconds
      push @array, 1;
      exit 0;
    }
    push @pids, $pid;
  }

  waitpid $_, 0 for @pids;

  cmp_deeply \@array, [qw/0 1 1 1 1 1 1/], 'race condition avoided';
}
