use strict;
use warnings;

use Test::More tests => 8;
use Data::Dumper;

use_ok 'Rex::CMDB';
use_ok 'Rex::Commands';

Rex::Commands->import;
Rex::CMDB->import;

set(cmdb => {
   type => "YAML",
   path => "t/cmdb",
});

my $ntp = get(cmdb("ntp", "foo"));
ok($ntp->[0] eq "ntp1" && $ntp->[1] eq "ntp2", "got something from default.yml");

my $name = get(cmdb("name", "foo"));
ok($name eq "foo", "got name from foo.yml");

my $dns = get(cmdb("dns", "foo"));
ok($dns->[0] eq "1.1.1.1" && $dns->[1] eq "2.2.2.2", "got dns from env/default.yml");

my $vhost = get(cmdb("vhost", "foo"));
ok($vhost->{name} eq "foohost" && $vhost->{doc_root} eq "/var/www", "got vhost from env/foo.yml");

$ntp = undef;
$ntp = get(cmdb("ntp"));
ok($ntp->[0] eq "ntp1" && $ntp->[1] eq "ntp2", "got something from default.yml");

$dns = undef;
$dns = get(cmdb("dns"));
ok($dns->[0] eq "1.1.1.1" && $dns->[1] eq "2.2.2.2", "got dns from env/default.yml");





