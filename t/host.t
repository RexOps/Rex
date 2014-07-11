use strict;
use warnings;

use Test::More;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Host';

Rex::Commands->import();
Rex::Commands::Host->import();

my @content = eval { local (@ARGV) = ("t/hosts.ex"); <>; };
my @ret = Rex::Commands::Host::_parse_hosts(@content);

ok( $ret[0]->{host} eq "localhost", "got localhost" );
ok( $ret[0]->{ip} eq "127.0.0.1",   "got 127.0.0.1" );

@ret = get_host( "mango", @content );
ok( $ret[0]->{ip} eq "192.168.2.23",       "got 192.168.2.23 by alias" );
ok( $ret[0]->{host} eq "mango.rexify.org", "got mango.rexify.org by alias" );

@content = eval { local (@ARGV) = ("t/hosts.ex2"); <>; };
@ret = Rex::Commands::Host::_parse_hosts(@content);

ok( $ret[0]->{host} eq "localhost",  "got localhost" );
ok( $ret[0]->{ip} eq "127.0.0.1",    "got 127.0.0.1" );
ok( $ret[2]->{host} eq "rexify.org", "got rexify.org" );
ok( $ret[2]->{ip} eq "1.2.3.4",      "got 1.2.3.4" );

@ret = get_host( "rexify.org", @content );
ok( $ret[0]->{ip} eq "1.2.3.4",      "got 1.2.3.4 from get_host" );
ok( $ret[0]->{host} eq "rexify.org", "got rexify.org from get_host" );

done_testing();
