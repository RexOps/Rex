
package main;

use Test::More tests => 4;
use Rex -base;

task(
  "test1",
  sub {
    my $x = param_lookup("name", "foo");
    my $tp = template(\'<%= $name %>');
    
    is($x, "foo", "got default value");
    is($tp, "foo", "got default value in template");
  }
);

task(
  "test2",
  sub {
    my $x = param_lookup("name", "foo");
    my $tp = template(\'<%= $name %>');
    
    is($x, "rex", "got parameter value");
    is($tp, "rex", "got parameter value in template");
  }
);



test1();
test2({name => "rex"});


