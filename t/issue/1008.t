use strict;
use warnings;

use Rex::Helper::IP;

use Test::More tests => 16;

my $ok = 0;

my $ipv4        = "192.168.178.22";
my $ipv4_port   = "192.168.178.22:2222";
my $ipv4_port_s = "192.168.178.22/2222";

my $ipv6      = "fe80::a00:27ff:fe36:9377";
my $ipv6_port = "fe80::a00:27ff:fe36:9377/3333";

my $hostname        = "blah01";
my $hostname_port   = "blah01:4444";
my $hostname_port_s = "blah01/4444";

my ( $s, $p );

( $s, $p ) = Rex::Helper::IP::get_server_and_port($ipv4);
is( $s, "192.168.178.22", "got v4 ip" );
is( $p, undef,            "got no port from v4 ip" );

( $s, $p ) = ( undef, undef );
( $s, $p ) = Rex::Helper::IP::get_server_and_port($ipv4_port);
is( $s, "192.168.178.22", "got v4 ip with port" );
is( $p, 2222,             "got port from v4 ip with colon" );

( $s, $p ) = ( undef, undef );
( $s, $p ) = Rex::Helper::IP::get_server_and_port($ipv4_port_s);
is( $s, "192.168.178.22", "got v4 ip with port with slash" );
is( $p, 2222,             "got port from v4 ip with slash" );

( $s, $p ) = ( undef, undef );
( $s, $p ) = Rex::Helper::IP::get_server_and_port($ipv6);
is( $s, "fe80::a00:27ff:fe36:9377", "got v6 ip" );
is( $p, undef,                      "got no port from v6 ip" );

( $s, $p ) = ( undef, undef );
( $s, $p ) = Rex::Helper::IP::get_server_and_port($ipv6_port);
is( $s, "fe80::a00:27ff:fe36:9377", "got v6 ip with port" );
is( $p, 3333,                       "got port from v6 ip with colon" );

( $s, $p ) = Rex::Helper::IP::get_server_and_port($hostname);
is( $s, "blah01", "got hostname" );
is( $p, undef,    "got no port from hostname" );

( $s, $p ) = ( undef, undef );
( $s, $p ) = Rex::Helper::IP::get_server_and_port($hostname_port);
is( $s, "blah01", "got host with port" );
is( $p, 4444,     "got port from hostname with colon" );

( $s, $p ) = ( undef, undef );
( $s, $p ) = Rex::Helper::IP::get_server_and_port($hostname_port_s);
is( $s, "blah01", "got host with port with slash" );
is( $p, 4444,     "got port from host with slash" );
