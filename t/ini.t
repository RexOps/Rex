use Test::More tests => 13;
use Data::Dumper;

use_ok 'Rex::Group::Lookup::INI';
use_ok 'Rex::Group';

Rex::Group::Lookup::INI->import;

groups_file("t/test.ini");

my %groups = Rex::Group->get_groups;

ok(scalar(@{ $groups{frontends} }) == 5, "frontends 5 servers");
ok(scalar(@{ $groups{backends} }) == 3, "frontends 3 servers");
ok($groups{frontends}->[0] eq "fe01", "got fe01");
ok($groups{frontends}->[1] eq "fe02", "got fe02");
ok($groups{frontends}->[2] eq "fe03", "got fe03");
ok($groups{frontends}->[3] eq "fe04", "got fe04");
ok($groups{frontends}->[4] eq "fe05", "got fe05");

ok($groups{backends}->[0] eq "be01", "got be01");
ok($groups{backends}->[1] eq "be02", "got be02");
ok($groups{backends}->[2] eq "be04", "got be04");

ok($groups{db}->[0] eq "db[01..02]", "got db[01..02]");

