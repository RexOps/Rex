use Data::Dumper;
use Test::More tests => 26;
use_ok 'Rex::Hardware::Network::Linux';
use_ok 'Rex::Helper::Hash';

my $in = eval { local(@ARGV, $/) = ("t/ifconfig.out1"); <>; };
my $info = Rex::Hardware::Network::Linux::_parse_ifconfig($in);

ok($info->{broadcast} eq "10.18.1.255", "ex1 / broadcast");
ok($info->{ip} eq "10.18.1.107", "ex1 / ip");
ok($info->{netmask} eq "255.255.255.0", "ex1 / netmask");
ok($info->{mac} eq "00:16:3e:7f:fc:3a", "ex1 / mac");

my $f = {};
hash_flatten({eth0 => $info}, $f, "_");
ok($f->{eth0_mac} eq "00:16:3e:7f:fc:3a", "ex1 / flatten / mac");
ok($f->{eth0_ip} eq "10.18.1.107", "ex1 / flatten / ip");
ok($f->{eth0_netmask} eq "255.255.255.0", "ex1 / flatten / netmask");
ok($f->{eth0_broadcast} eq "10.18.1.255", "ex1 / flatten / broadcast");

$in = eval { local(@ARGV, $/) = ("t/ifconfig.out2"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ifconfig($in);

ok(!$info->{broadcast}, "ex2 / broadcast");
ok(!$info->{ip}, "ex2 / ip");
ok(!$info->{netmask}, "ex2 / netmask");
ok($info->{mac} eq "fe:ff:ff:ff:ff:ff", "ex2 / mac");

$f = {};
hash_flatten({"vif1.0" => $info}, $f, "_");
ok($f->{"vif1.0_mac"} eq "fe:ff:ff:ff:ff:ff", "ex2 / flatten / mac");
ok(!$f->{"vif1.0_ip"}, "ex2 / flatten / ip");
ok(!$f->{"vif1.0_netmask"}, "ex2 / flatten / netmask");
ok(!$f->{"vif1.0_broadcast"}, "ex2 / flatten / broadcast");

$in = eval { local(@ARGV, $/) = ("t/ip.out1"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ip($in);

is($info->{ip}, "10.20.30.40", "ip / ip");
is($info->{netmask}, "255.255.255.0", "ip / netmask");
is($info->{broadcast}, "10.20.30.255", "ip / broadcast");
is($info->{mac}, "aa:bb:cc:dd:ee:ff", "ip / mac");

$f = {};
hash_flatten({"wlp2s0" => $info}, $f, "_");
is($f->{"wlp2s0_mac"}, "aa:bb:cc:dd:ee:ff", "ip / flatten / mac");
is($f->{"wlp2s0_ip"}, "10.20.30.40", "ip / flatten / ip");
is($f->{"wlp2s0_netmask"}, "255.255.255.0", "ip / flatten / netmask");
is($f->{"wlp2s0_broadcast"}, "10.20.30.255", "ip / flatten / broadcast");
