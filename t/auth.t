#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 49;
use Test::Warnings;

use Rex::Commands;
use Rex::Group;

{
  no warnings 'once';
  $::QUIET = 1;
}

group( "srvgr1", "srv1" );
group( "srvgr2", "srv2", "srv3" );

delete $ENV{REX_USER};

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
is( $auth->{user},        "root1" );
is( $auth->{password},    "pass1" );
is( $auth->{private_key}, "priv.key1" );
is( $auth->{public_key},  "pub.key1" );

$auth = Rex::TaskList->create()->get_task("testa2")->{auth};
is( $auth->{user},        "root2" );
is( $auth->{password},    "pass2" );
is( $auth->{private_key}, "priv.key2" );
is( $auth->{public_key},  "pub.key2" );

$auth = Rex::TaskList->create()->get_task("testa3")->{auth};
is( $auth->{user},        "root3" );
is( $auth->{password},    "pass3" );
is( $auth->{private_key}, "priv.key3" );
is( $auth->{public_key},  "pub.key3" );

my $task_b1 = Rex::TaskList->create()->get_task("testb1");
$auth = $task_b1->{auth};
is( $auth->{user},        "root2" );
is( $auth->{password},    "pass2" );
is( $auth->{private_key}, "priv.key2" );
is( $auth->{public_key},  "pub.key2" );

my $servers = $task_b1->server;
for my $server ( @{$servers} ) {
  $auth = $task_b1->merge_auth($server);

  is( $auth->{user},        "root2" );
  is( $auth->{password},    "pass2" );
  is( $auth->{private_key}, "priv.key2" );
  is( $auth->{public_key},  "pub.key2" );
}

my $task_b2 = Rex::TaskList->create()->get_task("testb2");
$servers = $task_b2->server;
for my $server ( @{$servers} ) {
  $auth = $task_b2->merge_auth($server);

  is( $auth->{user},        "root2" );
  is( $auth->{password},    "pass2" );
  is( $auth->{private_key}, "priv.key2" );
  is( $auth->{public_key},  "pub.key2" );
}

my $task_b3 = Rex::TaskList->create()->get_task("testb3");
$servers = $task_b3->server;
for my $server ( @{$servers} ) {
  $auth = $task_b3->merge_auth($server);

  is( $auth->{user},        "root2" );
  is( $auth->{password},    "pass2" );
  is( $auth->{private_key}, "priv.key2" );
  is( $auth->{public_key},  "pub.key2" );
}

auth(
  for         => "testa4",
  user        => "baruser",
  password    => "barpass",
  private_key => "testa4.priv",
  public_key  => "testa4.pub"
);

task(
  "testa4",
  sub {
  }
);

$auth = Rex::TaskList->create()->get_task("testa4")->{auth};
is( $auth->{user},        "baruser" );
is( $auth->{password},    "barpass" );
is( $auth->{private_key}, "testa4.priv" );
is( $auth->{public_key},  "testa4.pub" );

$ENV{REX_USER} = "root5";

user("toor5");
password("pass5");
private_key("testa5.priv");
public_key("testa5.pub");

task(
  "testa5",
  sub {
  }
);

$auth = Rex::TaskList->create()->get_task("testa5")->{auth};
is( $auth->{user},        "root5" );
is( $auth->{password},    "pass5" );
is( $auth->{private_key}, "testa5.priv" );
is( $auth->{public_key},  "testa5.pub" );
