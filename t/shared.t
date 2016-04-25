use strict;
use warnings;

BEGIN {
  use Test::More tests => 1;
  use Test::Deep;
  use Time::HiRes;
  use Rex::Shared::Var;
  share('@race_array');
}

# Sleeping in a test is not ideal.  But can't replace Time::HiRes::usleep()
# with POSIX::pause() because kill doesn't send signals on win32. See
# 'perldoc -f kill', 'perldoc perlport' and
# https://github.com/RexOps/Rex/pull/774

@race_array = (0);
my @pids;

for my $i ( 0 .. 5 ) {
  my $pid = fork();
  if ( $pid == 0 ) {

    # child
    Time::HiRes::usleep 100_000; # .1 seconds
    push @race_array, 1;
    exit 0;
  }
  push @pids, $pid;
}

waitpid $_, 0 for @pids;

cmp_deeply \@race_array, [qw/0 1 1 1 1 1 1/], 'race condition avoided';
