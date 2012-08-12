use strict;
use warnings;

use Test::More tests => 99;
use Data::Dumper;


use_ok 'Rex';
use_ok 'Rex::Commands';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';

Rex->import(-feature => 0.31);
Rex::Commands->import();

user("root3");
password("pass3");
private_key("priv.key3");
public_key("pub.key3");

no warnings;
$::FORCE_SERVER = "server1 foo[01..10]";
use warnings;

group("forcetest1", "bla1", "blah2");

task("tasktest3", "group", "forcetest1", sub {});

my @servers = Rex::Group->get_group("forcetest1");
ok($servers[0] eq "bla1", "forceserver - 1");


my $task = Rex::TaskList->create()->get_task("tasktest3");
my @all_server = @{ $task->server };

ok($all_server[0] eq "server1", "forceserver - task - 0");
ok($all_server[1] eq "foo01", "forceserver - task - 1");
ok($all_server[5] eq "foo05", "forceserver - task - 5");
ok($all_server[10] eq "foo10", "forceserver - task - 10");

for my $server (@all_server) {
   my $auth = $task->merge_auth($server);
   ok($auth->{user} eq "root3", "merge_auth - user");
   ok($auth->{password} eq "pass3", "merge_auth - pass");
   ok($auth->{public_key} eq "pub.key3", "merge_auth - pub");
   ok($auth->{private_key} eq "priv.key3", "merge_auth - priv");
}

auth(for => "tasktest3", user => "jan", password => "foo");
for my $server (@all_server) {
   my $auth = $task->merge_auth($server);
   ok($auth->{user} eq "jan", "merge_auth - user");
   ok($auth->{password} eq "foo", "merge_auth - pass");
   ok($auth->{public_key} eq "pub.key3", "merge_auth - pub");
   ok($auth->{private_key} eq "priv.key3", "merge_auth - priv");
}

