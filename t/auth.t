use strict;
use warnings;

use Test::More tests => 48;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';

Rex::Commands->import();

group( "srvgr1", "srv1" );
group( "srvgr2", "srv2", "srv3" );

user("root1");
password("pass1");
private_key("priv.key1");
public_key("pub.key1");

task(
  "testa1",
  sub {
  }
);

user("root2");
password("pass2");
private_key("priv.key2");
public_key("pub.key2");

auth(
  for         => "srvgr1",
  user        => "foouser",
  password    => "foopass",
  private_key => "foo.priv",
  public_key  => "foo.pub"
);

task(
  "testb1",
  group => "srvgr1",
  sub {
  }
);

task(
  "testb2",
  group => "srvgr2",
  sub {
  }
);

task(
  "testb3",
  group => [ "srvgr1", "srvgr2" ],
  sub {
  }
);

task(
  "testa2",
  sub {
  }
);

user("root3");
password("pass3");
private_key("priv.key3");
public_key("pub.key3");

task(
  "testa3",
  sub {
  }
);

my $auth = Rex::TaskList->create()->get_task("testa1")->{auth};
ok( $auth->{user} eq "root1" );
ok( $auth->{password} eq "pass1" );
ok( $auth->{private_key} eq "priv.key1" );
ok( $auth->{public_key} eq "pub.key1" );

$auth = Rex::TaskList->create()->get_task("testa2")->{auth};
ok( $auth->{user} eq "root2" );
ok( $auth->{password} eq "pass2" );
ok( $auth->{private_key} eq "priv.key2" );
ok( $auth->{public_key} eq "pub.key2" );

$auth = Rex::TaskList->create()->get_task("testa3")->{auth};
ok( $auth->{user} eq "root3" );
ok( $auth->{password} eq "pass3" );
ok( $auth->{private_key} eq "priv.key3" );
ok( $auth->{public_key} eq "pub.key3" );

my $task_b1 = Rex::TaskList->create()->get_task("testb1");
$auth = $task_b1->{auth};
ok( $auth->{user} eq "root2" );
ok( $auth->{password} eq "pass2" );
ok( $auth->{private_key} eq "priv.key2" );
ok( $auth->{public_key} eq "pub.key2" );

my $servers = $task_b1->server;
for my $server ( @{$servers} ) {
  $auth = $task_b1->merge_auth($server);

  ok( $auth->{user} eq "root2" );
  ok( $auth->{password} eq "pass2" );
  ok( $auth->{private_key} eq "priv.key2" );
  ok( $auth->{public_key} eq "pub.key2" );
}

my $task_b2 = Rex::TaskList->create()->get_task("testb2");
$servers = $task_b2->server;
for my $server ( @{$servers} ) {
  $auth = $task_b2->merge_auth($server);

  ok( $auth->{user} eq "root2" );
  ok( $auth->{password} eq "pass2" );
  ok( $auth->{private_key} eq "priv.key2" );
  ok( $auth->{public_key} eq "pub.key2" );
}

my $task_b3 = Rex::TaskList->create()->get_task("testb3");
$servers = $task_b3->server;
for my $server ( @{$servers} ) {
  $auth = $task_b3->merge_auth($server);

  ok( $auth->{user} eq "root2" );
  ok( $auth->{password} eq "pass2" );
  ok( $auth->{private_key} eq "priv.key2" );
  ok( $auth->{public_key} eq "pub.key2" );
}

