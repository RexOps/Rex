use strict;
use warnings;

use Test::More tests => 10;

use Cwd qw(realpath);
use Rex::Config;

Rex::Config->set( "test", "foobar" );
is( Rex::Config->get("test"), "foobar", "setting scalars" );

Rex::Config->set( "test_a", [qw/one two three/] );
is( Rex::Config->get("test_a")->[1], "two", "setting arrayRef" );
is_deeply(
  Rex::Config->get('test_a'),
  [qw/one two three/], "compare complete arrayRef",
);

Rex::Config->set( "test_a", [qw/four/] );
ok(
  Rex::Config->get("test_a")->[-1] eq "four"
    && Rex::Config->get("test_a")->[0] eq "one",
  "adding more to arrayRef"
);
is_deeply(
  Rex::Config->get('test_a'),
  [qw/one two three four/], "compare complete arrayRef",
);

Rex::Config->set( "test_h", { name => "john" } );
is( Rex::Config->get("test_h")->{"name"}, "john", "setting hashRef" );
is_deeply( Rex::Config->get('test_h'), { name => 'john' }, 'check test_h' );

Rex::Config->set( "test_h", { surname => "doe" } );
ok(
  Rex::Config->get("test_h")->{"surname"} eq "doe"
    && Rex::Config->get("test_h")->{"name"} eq "john",
  "adding more to hashRef"
);
is_deeply(
  Rex::Config->get('test_h'),
  { name => 'john', surname => 'doe' },
  'check test_h'
);

Rex::Config::read_config_file( realpath('t/config.yml') );

is( Rex::Config->get_user, 'configuser', 'user from config file' );

1;
