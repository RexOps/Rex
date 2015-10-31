package MyTest;

use Rex -base;
use Rex::Resource::Common;
use Test::More;

$::QUIET = 1;

resource "foo", sub {
  my $test_name = resource_name;
  my $mode = param_lookup "mode", "0755";

  is( $test_name, "testname", "resource name is testname" );
  is( $mode,      "0666",     "got mode 0666" );
};

1;

package main;

use Rex -base;
use Test::More;

use Rex::CMDB;
use Rex::Commands;

import MyTest;

set(
  cmdb => {
    type => "YAML",
    path => "t/cmdb",
  }
);

use Test::More tests => 2;
use Rex -base;

task(
  "test1",
  sub {
    MyTest::foo("testname");
  }
);

test1();

