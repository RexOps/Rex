use strict;
use warnings;

use Rex::CLI;

use Test::More tests => 2;

my $ok = 0;

eval {
  Rex::CLI::load_rexfile("t/issue/513_t1.rex");
  $ok = 1;
};

is( $ok, 1, "Rexfile with false return value was loaded successfull." );

$ok = 0;

eval {
  Rex::CLI::load_rexfile("t/issue/513_t2.rex");
  $ok = 1;
};

is( $ok, 1, "Rexfile with true return value was loaded successfull." );

