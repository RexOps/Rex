use strict;
use warnings;

use Test::More tests => 7;

use_ok 'Rex';
use_ok 'Rex::Config';

Rex::Config->set("test", "foobar");
ok(Rex::Config->get("test") eq "foobar", "setting scalars");

Rex::Config->set("test_a", [qw/one two three/]);
ok(Rex::Config->get("test_a")->[1] eq "two", "setting arrayRef");

Rex::Config->set("test_a", [qw/four/]);
ok(Rex::Config->get("test_a")->[-1] eq "four" && Rex::Config->get("test_a")->[0] eq "one", "adding more to arrayRef");


Rex::Config->set("test_h", {name => "john"});
ok(Rex::Config->get("test_h")->{"name"} eq "john", "setting hashRef");

Rex::Config->set("test_h", {surname => "doe"});
ok(Rex::Config->get("test_h")->{"surname"} eq "doe" && Rex::Config->get("test_h")->{"name"} eq "john", "adding more to hashRef");



1;

