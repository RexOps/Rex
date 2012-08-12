use strict;
use warnings;

use Test::More tests => 20;
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

user("root1");
password("pass1");
private_key("priv.key1");
public_key("pub.key1");

task("testa1", sub {
});

user("root2");
password("pass2");
private_key("priv.key2");
public_key("pub.key2");

task("testa2", sub {
});

user("root3");
password("pass3");
private_key("priv.key3");
public_key("pub.key3");

task("testa3", sub {
});

my $auth = Rex::TaskList->create()->get_task("testa1")->{auth};
ok($auth->{user} eq "root1");
ok($auth->{password} eq "pass1");
ok($auth->{private_key} eq "priv.key1");
ok($auth->{public_key} eq "pub.key1");

$auth = Rex::TaskList->create()->get_task("testa2")->{auth};
ok($auth->{user} eq "root2");
ok($auth->{password} eq "pass2");
ok($auth->{private_key} eq "priv.key2");
ok($auth->{public_key} eq "pub.key2");

$auth = Rex::TaskList->create()->get_task("testa3")->{auth};
ok($auth->{user} eq "root3");
ok($auth->{password} eq "pass3");
ok($auth->{private_key} eq "priv.key3");
ok($auth->{public_key} eq "pub.key3");



