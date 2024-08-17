#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 35;
use Test::Warnings;

SKIP: {

  eval { require String::Escape };

  skip 'Missing String::Escape for INI file support.', 34 if $@;

  require Rex::Group::Lookup::INI;
  Rex::Group::Lookup::INI->import;

  use Rex::Group;
  use Rex::Commands;

  no warnings 'once';

  $::QUIET = 1;

  groups_file("t/test.ini");

  my %groups = Rex::Group->get_groups;

  is( scalar( @{ $groups{frontends} } ), 5, "frontends 5 servers" );
  is( scalar( @{ $groups{backends} } ),  3, "backends 3 servers" );
  ok( grep { $_ eq "fe01" } @{ $groups{frontends} }, "got fe01" );
  ok( grep { $_ eq "fe02" } @{ $groups{frontends} }, "got fe02" );
  ok( grep { $_ eq "fe03" } @{ $groups{frontends} }, "got fe03" );
  ok( grep { $_ eq "fe04" } @{ $groups{frontends} }, "got fe04" );
  ok( grep { $_ eq "fe05" } @{ $groups{frontends} }, "got fe05" );

  ok( grep { $_ eq "be01" } @{ $groups{backends} }, "got be01" );
  ok( grep { $_ eq "be02" } @{ $groups{backends} }, "got be02" );
  ok( grep { $_ eq "be04" } @{ $groups{backends} }, "got be04" );

  ok( grep { $_ eq "db[01..02]" } @{ $groups{db} }, "got db[01..02]" );

  ok( grep { $_ eq "[01..02]-cassandra" } @{ $groups{cassandra} },
    "got [01..02]-cassandra]" );

  ok( grep { $_ eq "[111..133/11]-voldemort" } @{ $groups{voldemort} },
    "got [111..133/11]-voldemort" );

  ok( grep { $_ eq "[1,3,7,01]-kiokudb" } @{ $groups{kiokudb} },
    "got [1,3,7,01]-kiokudb" );

  ok( grep { $_ eq "[1..3,5,9..21/3]-riak" } @{ $groups{riak} },
    "got [1..3,5,9..21/3]-riak" );

  ok( grep { $_ eq "redis01" } @{ $groups{redis} }, "got redis01" );
  ok( grep { $_ eq "redis02" } @{ $groups{redis} }, "got redis02" );
  ok( grep { $_ eq "be01" } @{ $groups{redis} },    "got be01 in redis" );
  ok( grep { $_ eq "be02" } @{ $groups{redis} },    "got be01 in redis" );
  ok( grep { $_ eq "be04" } @{ $groups{redis} },    "got be01 in redis" );

  ok( grep { $_ eq "redis01" } @{ $groups{memcache} },
    "got redis01 in memcache" );
  ok( grep { $_ eq "redis02" } @{ $groups{memcache} },
    "got redis02 in memcache" );
  ok( grep { $_ eq "be01" } @{ $groups{memcache} },
    "got be01 in redis in memcache" );
  ok( grep { $_ eq "be02" } @{ $groups{memcache} },
    "got be01 in redis in memcache" );
  ok( grep { $_ eq "be04" } @{ $groups{memcache} },
    "got be01 in redis in memcache" );
  ok( grep { $_ eq "memcache01" } @{ $groups{memcache} }, "got memcache01" );
  ok( grep { $_ eq "memcache02" } @{ $groups{memcache} }, "got memcache02" );

  delete $ENV{REX_USER};

  user("krimdomu");
  password("foo");
  pass_auth();

  my ($server) = grep { $_ eq "memcache02" } @{ $groups{memcache} };

  no_ssh(
    task(
      "mytask", $server,
      sub {
        is( connection()->server->option("services"),
          "apache,memcache", "got services inside task" );
      }
    )
  );

  my $task = Rex::TaskList->create()->get_task("mytask");

  my $auth = $task->merge_auth($server);
  is( $auth->{user},     "krimdomu", "got krimdomu user for memcache02" );
  is( $auth->{password}, "foo",      "got foo password for memcache02" );

  Rex::Config->set_use_server_auth(1);

  $auth = $task->merge_auth($server);
  is( $auth->{user},     "root",   "got root user for memcache02" );
  is( $auth->{password}, "foob4r", "got foob4r password for memcache02" );
  ok( $auth->{sudo}, "got sudo for memcache02" );

  is( $server->option("services"), "apache,memcache",
    "got services of server" );

  # don't fork the task
  Rex::TaskList->create()->set_in_transaction(1);
  Rex::Commands::do_task("mytask");
  Rex::TaskList->create()->set_in_transaction(0);
}
