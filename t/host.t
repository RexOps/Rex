use strict;
use warnings;

use Test::More tests => 10;

use Rex::Commands::Host;

my @content = eval { local (@ARGV) = ("t/hosts.ex"); <>; };
my @ret     = Rex::Commands::Host::_parse_hosts(@content);

is( $ret[0]->{host}, "localhost", "got localhost" );
is( $ret[0]->{ip},   "127.0.0.1", "got 127.0.0.1" );

@ret = get_host( "mango", @content );
is( $ret[0]->{ip},   "192.168.2.23",     "got 192.168.2.23 by alias" );
is( $ret[0]->{host}, "mango.rexify.org", "got mango.rexify.org by alias" );

@content = eval { local (@ARGV) = ("t/hosts.ex2"); <>; };
@ret     = Rex::Commands::Host::_parse_hosts(@content);

is( $ret[0]->{host}, "localhost",  "got localhost" );
is( $ret[0]->{ip},   "127.0.0.1",  "got 127.0.0.1" );
is( $ret[2]->{host}, "rexify.org", "got rexify.org" );
is( $ret[2]->{ip},   "1.2.3.4",    "got 1.2.3.4" );

@ret = get_host( "rexify.org", @content );
is( $ret[0]->{ip},   "1.2.3.4",    "got 1.2.3.4 from get_host" );
is( $ret[0]->{host}, "rexify.org", "got rexify.org from get_host" );
