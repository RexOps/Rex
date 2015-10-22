use strict;
use warnings;

BEGIN {
  use Test::More tests => 9;
  use Test::Deep;
  use Time::HiRes;
  use Rex::Shared::Var;
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

{
    # Sleeping in a test is not ideal.  But can't replace Time::HiRes::usleep()
    # with POSIX::pause() because kill doesn't send signals on win32. See
    # 'perldoc -f kill', 'perldoc perlport' and
    # https://github.com/RexOps/Rex/pull/774

    @array = (0);
    my @pids;

    for my $i (0..5) {
        my $pid = fork();
        if ($pid == 0) {
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
