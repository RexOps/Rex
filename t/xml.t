use Test::More;
use FindBin qw($Bin);

use_ok 'Rex::Group::Lookup::XML';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Transaction';

no warnings 'once';

$::QUIET = 1;

Rex::Commands->import;


Rex::Group::Lookup::XML->import;

groups_xml("$Bin/test.xml");
my %groups = Rex::Group->get_groups;

ok(scalar(@{ $groups{application} }) == 2, "2 application servers");
ok( join(',',@{ $groups{application} }) =~ m/machine0[21],machine0[21]/, "got machine02,machine01");
ok(scalar(@{ $groups{profiler} }) == 2, "2 profiler servers 2");

my ($server1)  = grep { m/\bmachine07\b/ } @{ $groups{profiler} };
my ($server2) = grep { m/\bmachine01\b/ } @{ $groups{application} };

Rex::TaskList->create()->set_in_transaction(1);
no_ssh(task("xml_task1", $server1, sub {
   ok(connection()->server->option("services") eq "nginx,docker", "got services inside task");
}));
Rex::Commands::do_task("xml_task1");

no_ssh(task("xml_task2", $server2, sub {
  ok(connection()->server->get_user()     eq 'root', "$server2 user is 'root'");
  ok(connection()->server->get_password() eq 'foob4r', "$server2 password is 'foob4r'");
}));
Rex::Commands::do_task("xml_task2");
Rex::TaskList->create()->set_in_transaction(0);


done_testing();
