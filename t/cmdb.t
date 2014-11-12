use strict;
use warnings;

use Test::More tests => 15;
use Data::Dumper;

use_ok 'Rex::CMDB';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::File';

Rex::Commands->import;
Rex::CMDB->import;

set(
  cmdb => {
    type => "YAML",
    path => "t/cmdb",
  }
);

my $ntp = get( cmdb( "ntp", "foo" ) );
ok( $ntp->[0] eq "ntp1" && $ntp->[1] eq "ntp2",
  "got something from default.yml" );

my $name = get( cmdb( "name", "foo" ) );
is( $name, "foo", "got name from foo.yml" );

my $dns = get( cmdb( "dns", "foo" ) );
ok( $dns->[0] eq "1.1.1.1" && $dns->[1] eq "2.2.2.2",
  "got dns from env/default.yml" );

my $vhost = get( cmdb( "vhost", "foo" ) );
ok( $vhost->{name} eq "foohost" && $vhost->{doc_root} eq "/var/www",
  "got vhost from env/foo.yml" );

$ntp = undef;
$ntp = get( cmdb("ntp") );
ok( $ntp->[0] eq "ntp1" && $ntp->[1] eq "ntp2",
  "got something from default.yml" );

$dns = undef;
$dns = get( cmdb("dns") );
ok( $dns->[0] eq "1.1.1.1" && $dns->[1] eq "2.2.2.2",
  "got dns from env/default.yml" );

my $all = get( cmdb( undef, "foo" ) );
is( $all->{ntp}->[0], "ntp1",    "got ntp1 from cmdb - all request" );
is( $all->{dns}->[1], "2.2.2.2", "got dns2 from cmdb - all request" );
is(
  $all->{vhost}->{name}, "foohost",
  "got vhost name from cmdb - all request"
);
is( $all->{name}, "foo", "got name from cmdb - all request" );

Rex::Config->set_register_cmdb_template(1);
my $content = 'Hello this is <%= $::name %>';
is( template( \$content, __no_sys_info__ => 1 ), "Hello this is defaultname",
  "get keys from CMDB" );

is(
  template( \$content, { name => "baz", __no_sys_info__ => 1 } ),
    "Hello this is baz",
  "overwrite keys from CMDB"
);

