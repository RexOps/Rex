use strict;
use warnings;

$::TEST_MODE = 1; $::TEST_MODE = 1;

use Test::More tests => 2;
use Data::Dumper;

use_ok 'Rex::Commands::Run';
Rex::Commands::Run->import;

my $f = run("ls -l");
ok($f->{cmd} eq "ls -l", "run command");

