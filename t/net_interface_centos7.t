use Test::More tests => 6;
use Rex::Hardware::Network::Linux;

my @in   = eval { local (@ARGV) = ("t/ip.out_centos7"); <>; };
my $info = Rex::Hardware::Network::Linux::_parse_ip(@in);

is( $info->{lo}->{netmask}, '255.0.0.0', 'loopback netmask' );
is( $info->{lo}->{ip},      '127.0.0.1', 'loopback ip' );

is( $info->{eth0}->{ip},        '10.211.55.171',     'eth0 ip' );
is( $info->{eth0}->{netmask},   '255.255.255.0',     'eth0 netmask' );
is( $info->{eth0}->{broadcast}, '10.211.55.255',     'eth0 broadcast' );
is( $info->{eth0}->{mac},       '00:1c:42:fe:5a:b5', 'eth0 mac' );

@in   = eval { local (@ARGV) = ("t/ip.out_centos7_alias"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ip(@in);

1;
