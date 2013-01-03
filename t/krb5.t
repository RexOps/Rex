use strict;
use warnings;

use Test::More;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';

Rex::Commands->import();

krb5_auth();
task("testa1", sub {
});

my $auth = Rex::TaskList->create()->get_task("testa1")->{auth};
ok(ref $auth eq 'HASH');

done_testing();
