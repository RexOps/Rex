use strict;
use warnings;

use Test::More tests => 129;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';

Rex->import( -feature => 0.31 );
Rex::Commands->import();

user("root3");
password("pass3");
private_key("priv.key3");
public_key("pub.key3");

key_auth();

no warnings;
ok( Rex::TaskList->create()->is_default_auth() == 0, "default auth off" );
use warnings;

group( "foo", "server1", "server2", "server3" );
group( "bar", "serv[01..10]" );

my @servers = Rex::Group->get_group("foo");
ok( $servers[0] eq "server1", "get_group" );
ok( $servers[2] eq "server3", "get_group" );

@servers = Rex::Group->get_group("bar");
@servers = $servers[0]->get_servers;
ok( $servers[0] eq "serv01", "get_group with evaluation" );
ok( $servers[5] eq "serv06", "get_group with evaluation" );

task( "authtest1", group => "foo", sub { } );
task( "authtest2", group => "bar", sub { } );
task( "authtest3", "srv001", sub { } );

my $task       = Rex::TaskList->create()->get_task("authtest3");
my @all_server = @{ $task->server };

for my $server (@all_server) {
  my $auth = $task->merge_auth($server);
  ok( $auth->{user} eq "root3",            "merge_auth - user" );
  ok( $auth->{password} eq "pass3",        "merge_auth - pass" );
  ok( $auth->{public_key} eq "pub.key3",   "merge_auth - pub" );
  ok( $auth->{private_key} eq "priv.key3", "merge_auth - priv" );
  ok( $auth->{auth_type} eq "key",         "merge_auth - auth" );
}

pass_auth();

for my $server (@all_server) {
  my $auth = $task->merge_auth($server);
  ok( $auth->{user} eq "root3",            "merge_auth - user" );
  ok( $auth->{password} eq "pass3",        "merge_auth - pass" );
  ok( $auth->{public_key} eq "pub.key3",   "merge_auth - pub" );
  ok( $auth->{private_key} eq "priv.key3", "merge_auth - priv" );
  ok( $auth->{auth_type} eq "pass",        "merge_auth - auth" );
}

auth( for => "bar", user => "jan", password => "foo" );

$task = Rex::TaskList->create()->get_task("authtest1");

@all_server = @{ $task->server };

for my $server (@all_server) {
  my $auth = $task->merge_auth($server);
  ok( $auth->{user} eq "root3",            "merge_auth - user" );
  ok( $auth->{password} eq "pass3",        "merge_auth - pass" );
  ok( $auth->{public_key} eq "pub.key3",   "merge_auth - pub" );
  ok( $auth->{private_key} eq "priv.key3", "merge_auth - priv" );
}

$task       = Rex::TaskList->create()->get_task("authtest2");
@all_server = @{ $task->server };

for my $server (@all_server) {
  my $auth = $task->merge_auth($server);
  ok( $auth->{user} eq "jan",              "merge_auth - user" );
  ok( $auth->{password} eq "foo",          "merge_auth - pass" );
  ok( $auth->{public_key} eq "pub.key3",   "merge_auth - pub" );
  ok( $auth->{private_key} eq "priv.key3", "merge_auth - priv" );
  ok( $auth->{auth_type} eq "try",         "merge_auth - auth_type" );
  ok( !$auth->{sudo},                      "merge_auth - sudo" );
}

auth(
  for         => "authtest1",
  user        => "deploy",
  password    => "baz",
  private_key => FALSE(),
  public_key  => FALSE(),
  sudo        => TRUE()
);

$task       = Rex::TaskList->create()->get_task("authtest1");
@all_server = @{ $task->server };

for my $server (@all_server) {
  my $auth = $task->merge_auth($server);
  ok( $auth->{user} eq "deploy",       "merge_auth - user" );
  ok( $auth->{password} eq "baz",      "merge_auth - pass" );
  ok( $auth->{public_key} == FALSE(),  "merge_auth - pub" );
  ok( $auth->{private_key} == FALSE(), "merge_auth - priv" );
  ok( $auth->{auth_type} eq "pass",    "merge_auth - auth_type" );
  ok( $auth->{sudo} == TRUE(),         "merge_auth - sudo" );
}

set( "key1", "val1" );
ok( get("key1") eq "val1", "got value of key1" );

set( "key1", "val2" );
ok( get("key1") eq "val2", "got new value of key1" );

set( "key2", [qw/one two three/] );
ok( get("key2")->[0] eq "one",   "got value of first item in key2" );
ok( get("key2")->[1] eq "two",   "got value of 2nd item in key2" );
ok( get("key2")->[2] eq "three", "got value of 3rd item in key2" );

set( "key2", [qw/four five/] );
ok( get("key2")->[0] eq "one",   "got value of first item in key2" );
ok( get("key2")->[1] eq "two",   "got value of 2nd item in key2" );
ok( get("key2")->[2] eq "three", "got value of 3rd item in key2" );
ok( get("key2")->[3] eq "four",  "got value of NEW first item in key2" );
ok( get("key2")->[4] eq "five",  "got value of NEW 2nd item in key2" );

set( "key3", { name => 'foo', surname => 'bar' } );
ok( get("key3")->{name} eq "foo",    "got value of name parameter in key3" );
ok( get("key3")->{surname} eq "bar", "got value of surname parameter in key3" );

set( "key3", { x1 => 'x', x2 => 'xx' } );
ok( get("key3")->{name} eq "foo",    "got value of name parameter in key3" );
ok( get("key3")->{surname} eq "bar", "got value of surname parameter in key3" );
ok( get("key3")->{x1} eq "x",  "got value of NEW name parameter x1 in key3" );
ok( get("key3")->{x2} eq "xx", "got value of NEW name parameter x2 in key3" );
