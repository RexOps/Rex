
package main;

use Test::More tests => 2;
use Rex -base;

task(
  "test1",
  sub {
    my $x = param_lookup("name", "foo");
    is($x, "foo", "got default value");
  }
);

task(
  "test2",
  sub {
    my $x = param_lookup("name", "foo");
    is($x, "rex", "got parameter value");
  }
);



test1();
test2({name => "rex"});


