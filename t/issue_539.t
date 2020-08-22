use Test::More tests => 16;
use Rex::Hardware::Network::Linux;
use Rex::Helper::Hash;

my @in   = eval { local (@ARGV) = ("t/ip.out_issue_539"); <>; };
my $info = Rex::Hardware::Network::Linux::_parse_ip(@in);

is( $info->{eth0}->{broadcast}, "192.168.178.255", "eth0 primary / broadcast" );
is( $info->{eth0}->{ip},        "192.168.178.81",  "eth0 primary / ip" );
is( $info->{eth0}->{netmask},   "255.255.255.0",   "eth0 primary / netmask" );
is( $info->{eth0}->{mac},       "08:00:27:4b:b8:48", "eth0 primary / mac" );

is( $info->{eth0_1}->{broadcast},
  "192.168.99.255", "eth0 secondary / broadcast" );
is( $info->{eth0_1}->{ip},      "192.168.99.37", "eth0 secondary / ip" );
is( $info->{eth0_1}->{netmask}, "255.255.255.0", "eth0 secondary / netmask" );
is( $info->{eth0_1}->{mac},     "08:00:27:4b:b8:48", "eth0 secondary / mac" );

my $f = {};
hash_flatten( $info, $f, "_" );
is( $f->{eth0_mac},     "08:00:27:4b:b8:48", "eth0 primary / flatten / mac" );
is( $f->{eth0_ip},      "192.168.178.81",    "eth0 primary / flatten / ip" );
is( $f->{eth0_netmask}, "255.255.255.0", "eth0 primary / flatten / netmask" );
is( $f->{eth0_broadcast}, "192.168.178.255",
  "eth0 primary / flatten / broadcast" );

is( $f->{eth0_1_mac}, "08:00:27:4b:b8:48", "eth0 secondary / flatten / mac" );
is( $f->{eth0_1_ip},  "192.168.99.37",     "eth0 secondary / flatten / ip" );
is( $f->{eth0_1_netmask}, "255.255.255.0",
  "eth0 secondary / flatten / netmask" );
is( $f->{eth0_1_broadcast},
  "192.168.99.255", "eth0 secondary / flatten / broadcast" );

