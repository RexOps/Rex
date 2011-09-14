use strict;
use warnings;

use Test::More tests => 21;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';

Rex::Commands->import();

user("test");
ok(Rex::Config->get_user eq "test", "setting user");

password("test");
ok(Rex::Config->get_password eq "test", "setting password");

sudo_password("test");
ok(Rex::Config->get_sudo_password eq "test", "setting password");

timeout(5);
ok(Rex::Config->get_timeout == 5, "setting timeout");

max_connect_retries(5);
ok(Rex::Config->get_max_connect_fails == 5, "setting max connect retries");

ok(length(get_random(5, 'a' .. 'z')) == 5, "get random string");

public_key("/tmp/pub.key");
ok(Rex::Config->get_public_key eq "/tmp/pub.key", "set public key");

private_key("/tmp/priv.key");
ok(Rex::Config->get_private_key eq "/tmp/priv.key", "set private key");

pass_auth();
ok(Rex::Config->get_password_auth, "password auth");

parallelism(5);
ok(Rex::Config->get_parallelism == 5, "set parallelism");
parallelism(1);

path("/bin", "/sbin");
ok(join(",", Rex::Config->get_path) eq "/bin,/sbin", "set path");

set("foo", "bar");
ok(get("foo") eq "bar", "set/get");

my @ret = Rex::Commands::evaluate_hostname("test[01..04]");
ok(join(",", @ret) eq "test01,test02,test03,test04", "evaluate hostname");

@ret = Rex::Commands::evaluate_hostname("test[1..4]");
ok(join(",", @ret) eq "test1,test2,test3,test4", "evaluate hostname without zeros");


