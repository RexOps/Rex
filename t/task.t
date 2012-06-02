use strict;
use warnings;

use Test::More tests => 31;

use_ok 'Rex::Task';
use_ok 'Rex::Commands';
Rex::Commands->import;

my $t1 = Rex::Task->new(name => "foo");

ok(ref($t1) eq "Rex::Task", "create teask object");

ok($t1->get_connection_type eq "Local", "get connection type for local");
ok($t1->is_local == 1, "is task local");
ok($t1->is_remote == 0, "is task not remote");

$t1->set_server("192.168.1.1");
ok($t1->server->[0] eq "192.168.1.1", "get/set server");

ok($t1->is_local == 0, "is task not local");

$t1->set_desc("Description");
ok($t1->desc eq "Description", "get/set description");

ok($t1->get_connection_type eq "SSH", "get connection type for ssh");
ok($t1->want_connect == 1, "want a connection?");
$t1->modify("no_ssh", 1);
ok($t1->want_connect == 0, "want no connection?");
ok($t1->get_connection_type eq "Fake", "get connection type for fake");
$t1->modify("no_ssh", 0);
ok($t1->want_connect == 1, "want a connection?");
ok($t1->get_connection_type eq "SSH", "get connection type for ssh");

$t1->set_user("root");
ok($t1->user eq "root", "get/set the user");
$t1->set_password("f00b4r");
ok($t1->password eq "f00b4r", "get/set the password");

ok($t1->name eq "foo", "get task name");

$t1->set_auth("user", "foo");
ok($t1->user eq "foo", "set auth user");
$t1->set_auth("password", "baz");
ok($t1->password eq "baz", "set auth password");

my $test_var = 0;
$t1->set_code(sub {
   $test_var = connection()->server;
});

ok(! $t1->connection->is_connected , "connection currently not established");
$t1->modify("no_ssh", 1);
$t1->connect("localtest");
ok($t1->connection->is_connected, "connection established");
$t1->run("localtest");
ok($test_var eq "localtest", "task run");
$t1->disconnect();

my $before_hook = 0;
$t1->delete_server;
ok($t1->is_remote == 0, "task is no more remote");
ok($t1->is_local == 1, "task is now local");

$t1->modify(before => sub {
   my $server = shift;
   my $server_ref = shift;

   $before_hook = 1;
   $$server_ref = "local02";
});

my $server = $t1->current_server;
$t1->run_hook(\$server, "before");

ok($before_hook == 1, "run before hook");
ok($t1->is_remote == 1, "task is now remote");
ok($t1->is_local == 0, "task is no more local");

$t1->modify(before => sub {
   my $server = shift;
   my $server_ref = shift;

   $before_hook = 2;
   $$server_ref = "<local>";
});

$server = $t1->current_server;
$t1->run_hook(\$server, "before");

ok($before_hook == 2, "run before hook - right direction");
ok($t1->is_remote == 0, "task is no not remote");
ok($t1->is_local == 1, "task is now local");



