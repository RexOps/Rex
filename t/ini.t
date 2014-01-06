use Test::More tests => 36;
use Data::Dumper;

use_ok 'Rex::Group::Lookup::INI';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Transaction';

$::QUIET = 1;

Rex::Commands->import;


Rex::Group::Lookup::INI->import;

groups_file("t/test.ini");

my %groups = Rex::Group->get_groups;

ok(scalar(@{ $groups{frontends} }) == 5, "frontends 5 servers");
ok(scalar(@{ $groups{backends} }) == 3, "frontends 3 servers");
ok(grep { $_ eq "fe01" } @{ $groups{frontends} }, "got fe01");
ok(grep { $_ eq "fe02" } @{ $groups{frontends} }, "got fe02");
ok(grep { $_ eq "fe03" } @{ $groups{frontends} }, "got fe03");
ok(grep { $_ eq "fe04" } @{ $groups{frontends} }, "got fe04");
ok(grep { $_ eq "fe05" } @{ $groups{frontends} }, "got fe05");

ok(grep { $_ eq "be01" } @{ $groups{backends} }, "got be01");
ok(grep { $_ eq "be02" } @{ $groups{backends} }, "got be02");
ok(grep { $_ eq "be04" } @{ $groups{backends} }, "got be04");

ok(grep { $_ eq "db[01..02]" } @{ $groups{db} }, "got db[01..02]");

ok(grep { $_ eq "redis01" } @{ $groups{redis} }, "got redis01");
ok(grep { $_ eq "redis02" } @{ $groups{redis} }, "got redis02");
ok(grep { $_ eq "be01" } @{ $groups{redis} }, "got be01 in redis");
ok(grep { $_ eq "be02" } @{ $groups{redis} }, "got be01 in redis");
ok(grep { $_ eq "be04" } @{ $groups{redis} }, "got be01 in redis");

ok(grep { $_ eq "redis01" } @{ $groups{memcache} }, "got redis01 in memcache");
ok(grep { $_ eq "redis02" } @{ $groups{memcache} }, "got redis02 in memcache");
ok(grep { $_ eq "be01" } @{ $groups{memcache} }, "got be01 in redis in memcache");
ok(grep { $_ eq "be02" } @{ $groups{memcache} }, "got be01 in redis in memcache");
ok(grep { $_ eq "be04" } @{ $groups{memcache} }, "got be01 in redis in memcache");
ok(grep { $_ eq "memcache01" } @{ $groups{memcache} }, "got memcache01");
ok(grep { $_ eq "memcache02" } @{ $groups{memcache} }, "got memcache02");

user("krimdomu");
password("foo");
pass_auth();

my ($server) = grep { $_ eq "memcache02" } @{ $groups{memcache} };

no_ssh(task("mytask", $server, sub {
   ok(connection()->server->option("services") eq "apache,memcache", "got services inside task");
}));

my $task = Rex::TaskList->create()->get_task("mytask");

my $auth = $task->merge_auth($server);
ok($auth->{user} eq "krimdomu", "got krimdomu user for memcache02");
ok($auth->{password} eq "foo", "got foo password for memcache02");

Rex::Config->set_use_server_auth(1);

$auth = $task->merge_auth($server);
ok($auth->{user} eq "root", "got root user for memcache02");
ok($auth->{password} eq "foob4r", "got foob4r password for memcache02");
ok($auth->{sudo}, "got sudo for memcache02");

ok($server->option("services") eq "apache,memcache", "got services of server");

# don't fork the task
Rex::TaskList->create()->set_in_transaction(1);
Rex::Commands::do_task("mytask");
Rex::TaskList->create()->set_in_transaction(0);
