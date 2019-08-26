use strict;
use warnings;

use File::Temp;
use Test::More tests => 21;

use Rex::Config;

my $ssh_cfg1 = <<EOF;

# Sample SSH config w/o equal signs
Host *
	StrictHostKeyChecking no
	UserKnownHostsFile=/dev/null

Host frontend1
Hostname fe80::1
User bogey
Port 35221

Host web
Hostname 192.168.1.1
User root 

EOF

my $ssh_cfg2 = <<EOF;

Host = frontend2
   Hostname = this.is.a.domain.tld
   User = 123
   Port = 1005

Host = some other hosts
Port = 3306

EOF

my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
ok( open( my $FH1, '>', $tempdir . '/cfg1' ), 'Opened cfg1' );
print $FH1 $ssh_cfg1;
ok( close($FH1), 'Closed cfg1' );

%Rex::Config::SSH_CONFIG_FOR = ();
Rex::Config::read_ssh_config_file( $tempdir . '/cfg1' );
my $c = \%Rex::Config::SSH_CONFIG_FOR;

is( $c->{'web'}->{'user'}, 'root' );
isnt( $c->{'web'}->{'user'}, 'root ' );
is( $c->{'web'}->{'hostname'}, '192.168.1.1' );

is( $c->{'frontend1'}->{'user'},     'bogey' );
is( $c->{'frontend1'}->{'hostname'}, 'fe80::1' );
is( $c->{'frontend1'}->{'port'},     35221 );

ok( open( my $FH2, '>', $tempdir . '/cfg2' ), 'Opened cfg2' );
print $FH2 $ssh_cfg2;
ok( close($FH2), 'Closed cfg2' );

%Rex::Config::SSH_CONFIG_FOR = ();
Rex::Config::read_ssh_config_file( $tempdir . '/cfg2' );

is( $c->{'frontend2'}->{'user'},     '123' );
is( $c->{'frontend2'}->{'hostname'}, 'this.is.a.domain.tld' );
is( $c->{'frontend2'}->{'port'},     1005 );

is( $c->{'some'}->{'port'},  '3306' );
is( $c->{'other'}->{'port'}, '3306' );
is( $c->{'hosts'}->{'port'}, '3306' );

my @lines = eval { local (@ARGV) = ("t/ssh_config.1"); <>; };
my %data  = Rex::Config::_parse_ssh_config(@lines);

ok( exists $data{"*"}, "Host * exists" );
ok(
  exists $data{"*"}->{stricthostkeychecking},
  "Host * / StrictHostKeyChecking exists"
);
ok(
  $data{"*"}->{stricthostkeychecking} eq "no",
  "Host * / StrictHostKeyChecking and contains 'no'"
);
ok(
  exists $data{"*"}->{userknownhostsfile},
  "Host * / UserKnownHostsFile exists"
);
ok(
  $data{"*"}->{userknownhostsfile} eq "/dev/null",
  "Host * / UserKnownHostsFile and contains '/dev/null'"
);

1;

