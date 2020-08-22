use Test::More tests => 44;
use Rex::Hardware::Network::Linux;
use Rex::Helper::Hash;

my @in   = eval { local (@ARGV) = ("t/ifconfig.out1"); <>; };
my $info = Rex::Hardware::Network::Linux::_parse_ifconfig(@in);

is( $info->{eth0}->{broadcast}, "10.18.1.255",       "ex1 / broadcast" );
is( $info->{eth0}->{ip},        "10.18.1.107",       "ex1 / ip" );
is( $info->{eth0}->{netmask},   "255.255.255.0",     "ex1 / netmask" );
is( $info->{eth0}->{mac},       "00:16:3e:7f:fc:3a", "ex1 / mac" );

my $f = {};
hash_flatten( $info, $f, "_" );
is( $f->{eth0_mac},       "00:16:3e:7f:fc:3a", "ex1 / flatten / mac" );
is( $f->{eth0_ip},        "10.18.1.107",       "ex1 / flatten / ip" );
is( $f->{eth0_netmask},   "255.255.255.0",     "ex1 / flatten / netmask" );
is( $f->{eth0_broadcast}, "10.18.1.255",       "ex1 / flatten / broadcast" );

@in   = eval { local (@ARGV) = ("t/ifconfig.out2"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ifconfig(@in);

ok( !$info->{"vif1.0"}->{broadcast}, "ex2 / broadcast" );
ok( !$info->{"vif1.0"}->{ip},        "ex2 / ip" );
ok( !$info->{"vif1.0"}->{netmask},   "ex2 / netmask" );
is( $info->{"vif1.0"}->{mac}, "fe:ff:ff:ff:ff:ff", "ex2 / mac" );

$f = {};
hash_flatten( $info, $f, "_" );
is( $f->{"vif1_0_mac"}, "fe:ff:ff:ff:ff:ff", "ex2 / flatten / mac" );
ok( !$f->{"vif1_0_ip"},        "ex2 / flatten / ip" );
ok( !$f->{"vif1_0_netmask"},   "ex2 / flatten / netmask" );
ok( !$f->{"vif1_0_broadcast"}, "ex2 / flatten / broadcast" );

@in   = eval { local (@ARGV) = ("t/ip.out1"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ip(@in);

is( $info->{wlp2s0}->{ip},        "10.20.30.40",       "ip / ip" );
is( $info->{wlp2s0}->{netmask},   "255.255.255.0",     "ip / netmask" );
is( $info->{wlp2s0}->{broadcast}, "10.20.30.255",      "ip / broadcast" );
is( $info->{wlp2s0}->{mac},       "aa:bb:cc:dd:ee:ff", "ip / mac" );

$f = {};
hash_flatten( $info, $f, "_" );
is( $f->{"wlp2s0_mac"},       "aa:bb:cc:dd:ee:ff", "ip / flatten / mac" );
is( $f->{"wlp2s0_ip"},        "10.20.30.40",       "ip / flatten / ip" );
is( $f->{"wlp2s0_netmask"},   "255.255.255.0",     "ip / flatten / netmask" );
is( $f->{"wlp2s0_broadcast"}, "10.20.30.255",      "ip / flatten / broadcast" );

$info = {};
@in   = eval { local (@ARGV) = ("t/ip.out2"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ip(@in);
is( $info->{eth1}->{ip},        "",                  "ip / ip" );
is( $info->{eth1}->{netmask},   "",                  "ip / netmask" );
is( $info->{eth1}->{broadcast}, "",                  "ip / broadcast" );
is( $info->{eth1}->{mac},       "00:1c:42:73:ad:3c", "ip / mac" );

@in   = eval { local (@ARGV) = ("t/ifconfig.out6"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ifconfig(@in);

is( $info->{eth0}->{broadcast}, "192.168.112.255", "(fc19) eth0 / broadcast" );
is( $info->{eth0}->{ip},        "192.168.112.182", "(fc19) eth0 / ip" );
is( $info->{eth0}->{netmask},   "255.255.255.0",   "(fc19) eth0 / netmask" );
is( $info->{eth0}->{mac},       "52:54:00:37:a8:e1", "(fc19) eth0 / mac" );

is( $info->{"eth0:1"}->{broadcast}, "1.2.255.255",
  "(fc19) eth0:1 / broadcast" );
is( $info->{"eth0:1"}->{ip},      "1.2.3.4",     "(fc19) eth0:1 / ip" );
is( $info->{"eth0:1"}->{netmask}, "255.255.0.0", "(fc19) eth0:1 / netmask" );
is( $info->{"eth0:1"}->{mac},     "52:54:00:37:a8:e1", "(fc19) eth0:1 / mac" );

@in   = eval { local (@ARGV) = ("t/ifconfig.out7"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ifconfig(@in);
is( $info->{ppp0}->{ip},        "123.117.251.17",  "ppp0 / ip" );
is( $info->{ppp0}->{netmask},   "255.255.255.255", "ppp0 / netmask" );
is( $info->{ppp0}->{broadcast}, "",                "ppp0 / broadcast" );
is( $info->{ppp0}->{mac},       "",                "ppp0 / mac" );

@in   = eval { local (@ARGV) = ("t/ip.out3"); <>; };
$info = Rex::Hardware::Network::Linux::_parse_ip(@in);
is( $info->{ppp0}->{ip},        "123.117.251.17",  "ppp0 / ip" );
is( $info->{ppp0}->{netmask},   "255.255.255.255", "ppp0 / netmask" );
is( $info->{ppp0}->{broadcast}, "",                "ppp0 / broadcast" );
is( $info->{ppp0}->{mac},       "",                "ppp0 / mac" );
