use Data::Dumper;
use Test::More tests => 7;
use_ok 'Rex::Hardware::Network::Linux';

my @in = eval { local (@ARGV) = ("t/ip.out_centos7"); <>; };
my $info = Rex::Hardware::Network::Linux::_parse_ip(@in);

ok($info->{lo}->{netmask} eq '255.0.0.0', 'loopback netmask');
ok($info->{lo}->{ip} eq '127.0.0.1', 'loopback ip');

ok($info->{eth0}->{ip} eq '10.211.55.171', 'eth0 ip');
ok($info->{eth0}->{netmask} eq '255.255.255.0', 'eth0 netmask');
ok($info->{eth0}->{broadcast} eq '10.211.55.255', 'eth0 broadcast');
ok($info->{eth0}->{mac} eq '00:1c:42:fe:5a:b5', 'eth0 mac');

@in = eval { local (@ARGV) = ("t/ip.out_centos7_alias"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ip(@in);

print STDERR Dumper $info;

1;
