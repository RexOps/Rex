#!/usr/bin/env perl

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use lib 'lib';

local $INC{'Net/OpenSSH/ShellQuoter.pm'} = 1;
require Rex::Commands::Gather;

my @should = qw(
  Fedora Redhat CentOS Rocky rocky RockyLinux AlmaLinux CentOSStream
  OracleLinux RedHatEnterprise RedHatEnterpriseServer
);
for my $os (@should) {
  ok( Rex::Commands::Gather::is_redhat($os), "is_redhat($os)" );
}

ok(
  !Rex::Commands::Gather::is_redhat('Red'),
  'is_redhat(Red) must not match via substring'
);
ok( !Rex::Commands::Gather::is_redhat('Debian'), 'is_redhat(Debian) is false' );

done_testing();
