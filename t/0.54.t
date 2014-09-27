use strict;
use warnings;

use Test::More tests => 15;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Commands';

Rex->import( -feature => 0.54 );
Rex::Commands->import;

set("key1", "val1");
ok(get("key1") eq "val1", "got value of key1");

set("key1", "val2");
ok(get("key1") eq "val2", "got new value of key1");

set("key2", [qw/one two three/]);
ok(get("key2")->[0] eq "one", "got value of first item in key2");
ok(get("key2")->[1] eq "two", "got value of 2nd item in key2");
ok(get("key2")->[2] eq "three", "got value of 3rd item in key2");

set("key2", [qw/four five/]);
ok(get("key2")->[0] eq "four", "got value of NEW first item in key2");
ok(get("key2")->[1] eq "five", "got value of NEW 2nd item in key2");

set("key3", {name => 'foo', surname => 'bar'});
ok(get("key3")->{name} eq "foo", "got value of name parameter in key3");
ok(get("key3")->{surname} eq "bar", "got value of surname parameter in key3");

set("key3", {x1 => 'x', x2 => 'xx'});
ok(get("key3")->{x1} eq "x", "got value of NEW name parameter x1 in key3");
ok(get("key3")->{x2} eq "xx", "got value of NEW name parameter x2 in key3");
ok(! exists get("key3")->{name}, "name parameter doesn't exists anymore");
ok(! exists get("key3")->{surname}, "surname parameter doesn't exists anymore");
