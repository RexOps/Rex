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

ok(scalar(@{ $groups{application} }) == 2, "application 2 servers");

# TODO: Perform more tests

done_testing();
