#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 19;
use Test::Warnings;

use Rex::Commands;

delete $ENV{REX_USER};

user("test");
is( Rex::Config->get_user, "test", "setting user" );

password("test");
is( Rex::Config->get_password, "test", "setting password" );

sudo_password("test");
is( Rex::Config->get_sudo_password, "test", "setting password" );

timeout(5);
is( Rex::Config->get_timeout, 5, "setting timeout" );

max_connect_retries(5);
is( Rex::Config->get_max_connect_fails, 5, "setting max connect retries" );

is( length( get_random( 5, 'a' .. 'z' ) ), 5, "get random string" );

public_key("/tmp/pub.key");
is( Rex::Config->get_public_key, "/tmp/pub.key", "set public key" );

private_key("/tmp/priv.key");
is( Rex::Config->get_private_key, "/tmp/priv.key", "set private key" );

pass_auth();
ok( Rex::Config->get_password_auth, "password auth" );

parallelism(5);
is( Rex::Config->get_parallelism, 5, "set parallelism" );
parallelism(1);

path( "/bin", "/sbin" );
is_deeply( [ Rex::Config->get_path ], [qw!/bin /sbin!], "set path" );

set( "foo", "bar" );
is( get("foo"), "bar", "set/get" );

my @ret = Rex::Commands::evaluate_hostname("test[01..04]");
is_deeply( \@ret, [qw/test01 test02 test03 test04/], "evaluate hostname" );

@ret = Rex::Commands::evaluate_hostname("test[01..04].rexify.org");
is_deeply(
  \@ret,
  [qw/test01.rexify.org test02.rexify.org test03.rexify.org test04.rexify.org/],
  "evaluate hostname / with domain"
);

@ret = Rex::Commands::evaluate_hostname("test[1..4]");
is_deeply(
  \@ret,
  [qw/test1 test2 test3 test4/],
  "evaluate hostname without zeros"
);

@ret = Rex::Commands::evaluate_hostname("test[1..4].rexify.org");
is_deeply(
  \@ret,
  [qw/test1.rexify.org test2.rexify.org test3.rexify.org test4.rexify.org/],
  "evaluate hostname with domainname / without zero"
);

@ret = Rex::Commands::evaluate_hostname("10.5.9.[8..11]");
is_deeply( \@ret, [qw/10.5.9.8 10.5.9.9 10.5.9.10 10.5.9.11/], "evaluate ip" );

@ret = Rex::Commands::evaluate_hostname("[1..3].host.domain");
is_deeply(
  \@ret,
  [qw/1.host.domain 2.host.domain 3.host.domain/],
  "evaluate leading range"
);
