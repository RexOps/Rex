
use Rex -base;
use Test::More;

use Rex::CMDB;
use Rex::Commands;

set(
  cmdb => {
    type => "YAML",
    path => "t/cmdb",
  }
);


use Test::More tests => 1;
use Rex -base;

task(
  "test1",
  sub {
    my $x = param_lookup("name", "foo");
    is($x, "defaultname", "got default value");
  }
);

test1();

