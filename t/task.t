use strict;
use warnings;
use Test::More;

my %have_mods = (
  'Net::SSH2'    => 1,
  'Net::OpenSSH' => 1,
);

for my $m ( keys %have_mods ) {
  my $have_mod = 1;
  eval "use $m;";
  if ($@) {
    $have_mods{$m} = 0;
  }
}

unless ( $have_mods{'Net::SSH2'} or $have_mods{'Net::OpenSSH'} ) {
  plan skip_all =>
    'SSH module not found. You need Net::SSH2 or Net::OpenSSH to connect to servers via SSH.';
}
else {
  plan tests => 36;
}

use Rex::Task;
use Rex::Commands;

{
  no warnings 'once';
  $::QUIET = 1;
}

my $t1 = Rex::Task->new( name => "foo" );

isa_ok( $t1, "Rex::Task", "create teask object" );

is( $t1->get_connection_type, "Local", "get connection type for local" );
is( $t1->is_local,            1,       "is task local" );
is( $t1->is_remote,           0,       "is task not remote" );

$t1->set_server("192.168.1.1");
is( $t1->server->[0], "192.168.1.1", "get/set server" );

is( $t1->is_local, 0, "is task not local" );

$t1->set_desc("Description");
is( $t1->desc, "Description", "get/set description" );

is(
  $t1->get_connection_type,
  ( $have_mods{"Net::OpenSSH"} && $^O !~ m/^MSWin/ ? "OpenSSH" : "SSH" ),
  "get connection type for ssh"
);
is( $t1->want_connect, 1, "want a connection?" );
$t1->modify( "no_ssh", 1 );
is( $t1->want_connect,        0,      "want no connection?" );
is( $t1->get_connection_type, "Fake", "get connection type for fake" );
$t1->modify( "no_ssh", 0 );
is( $t1->want_connect, 1, "want a connection?" );
is(
  $t1->get_connection_type,
  ( $have_mods{"Net::OpenSSH"} && $^O !~ m/^MSWin/ ? "OpenSSH" : "SSH" ),
  "get connection type for ssh"
);

Rex::Config->set( "connection" => "SSH" );
is( $t1->get_connection_type, "SSH", "get connection type for ssh" );

Rex::Config->set( "connection" => "OpenSSH" );
is( $t1->get_connection_type, "OpenSSH", "get connection type for ssh" );

$t1->set_user("root");
is( $t1->user, "root", "get/set the user" );
$t1->set_password("f00b4r");
is( $t1->password, "f00b4r", "get/set the password" );

is( $t1->name, "foo", "get task name" );

$t1->set_auth( "user", "foo" );
is( $t1->user, "foo", "set auth user" );
$t1->set_auth( "password", "baz" );
is( $t1->password, "baz", "set auth password" );

my $test_var = 0;
$t1->set_code(
  sub {
    $test_var = connection()->server;
  }
);

Rex::Config->set( "connection" => $have_mods{"Net::OpenSSH"}
    && $^O !~ m/^MSWin/ ? "OpenSSH" : "SSH" );
ok( !$t1->connection->is_connected, "connection currently not established" );
$t1->modify( "no_ssh", 1 );
$t1->connect("localtest");
ok( $t1->connection->is_connected, "connection established" );
$t1->run("localtest");
is( $test_var, "localtest", "task run" );
$t1->disconnect();

my $before_hook = 0;
$t1->delete_server;
is( $t1->is_remote, 0, "task is no more remote" );
is( $t1->is_local,  1, "task is now local" );

$t1->modify(
  before => sub {
    my $server     = shift;
    my $server_ref = shift;

    $before_hook = 1;
    $$server_ref = "local02";
  }
);

my $server = $t1->current_server;
$t1->run_hook( \$server, "before" );

is( $before_hook,   1, "run before hook" );
is( $t1->is_remote, 1, "task is now remote" );
is( $t1->is_local,  0, "task is no more local" );

$t1->modify(
  before => sub {
    my $server     = shift;
    my $server_ref = shift;

    $before_hook = 2;
    $$server_ref = "<local>";
  }
);

$server = $t1->current_server;
$t1->run_hook( \$server, "before" );

is( $before_hook,   2, "run before hook - right direction" );
is( $t1->is_remote, 0, "task is no not remote" );
is( $t1->is_local,  1, "task is now local" );

task(
  "ret_test1",
  sub {
    return "string";
  }
);

task(
  "ret_test2",
  sub {
    return ( "e1", "e2" );
  }
);

task(
  "param_test1",
  sub {
    my $param = shift;
    is_deeply(
      $param,
      { name => "foo" },
      "First parameter to task is a hashRef"
    );
  }
);

task(
  "param_test2",
  sub {
    is_deeply( \@_, [ "city", "bar" ], "Parameters are a list (length 2)." );
  }
);

task(
  "param_test3",
  sub {
    is_deeply(
      \@_,
      [ "blah", "blub", "bumm" ],
      "Parameters are a list (length 3)."
    );
  }
);

my $s = ret_test1();
is( $s, "string", "task successfully returned a string" );

my @l = ret_test2();
is_deeply( \@l, [ "e1", "e2" ], "task successfully returned a list" );

param_test1( { name => "foo" } );
param_test2( city => "bar" );
param_test3( "blah", "blub", "bumm" );

