use strict;
use warnings;

use Test::More;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Commands';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'List::MoreUtils';

Rex->import( -feature => 0.31 );
Rex::Commands->import();

user("root3");
password("pass3");
private_key("priv.key3");
public_key("pub.key3");

no warnings;
$::FORCE_SERVER = "server1 foo[01..10]";
use warnings;

group( "forcetest1", "bla1", "blah2", "bla1" );

task( "tasktest3", "group", "forcetest1", sub { } );

my @servers = Rex::Group->get_group("forcetest1");
is( $servers[0], "bla1", "forceserver - 1" );
ok( !defined $servers[2], "group - servername uniq" );

my $task       = Rex::TaskList->create()->get_task("tasktest3");
my @all_server = @{ $task->server };

is( $all_server[0],  "server1", "forceserver - task - 0" );
is( $all_server[1],  "foo01",   "forceserver - task - 1" );
is( $all_server[5],  "foo05",   "forceserver - task - 5" );
is( $all_server[10], "foo10",   "forceserver - task - 10" );

for my $server (@all_server) {
  my $auth = $task->merge_auth($server);
  is( $auth->{user},        "root3",     "merge_auth - user" );
  is( $auth->{password},    "pass3",     "merge_auth - pass" );
  is( $auth->{public_key},  "pub.key3",  "merge_auth - pub" );
  is( $auth->{private_key}, "priv.key3", "merge_auth - priv" );
}

auth( for => "tasktest3", user => "jan", password => "foo" );
for my $server (@all_server) {
  my $auth = $task->merge_auth($server);
  is( $auth->{user},        "jan",       "merge_auth - user" );
  is( $auth->{password},    "foo",       "merge_auth - pass" );
  is( $auth->{public_key},  "pub.key3",  "merge_auth - pub" );
  is( $auth->{private_key}, "priv.key3", "merge_auth - priv" );
}

group( "duplicated_by_list", "s[1..3,2..4]" );
my @cleaned_servers = Rex::Group->get_group("duplicated_by_list");
is_deeply [ $cleaned_servers[0]->get_servers ], [
  qw/
    s1 s2 s3 s4
    /
  ],
  "duplicated_by_list";

done_testing();
