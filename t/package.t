#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 1;
use Test::Deep;

use Rex::Pkg::Test;

my $pkg = Rex::Pkg::Test->new;

subtest 'package list diffs' => sub {
  plan tests => 1;

  my @plist1 = (
    { name => 'vim', version => '1.0' },
    { name => 'mc',  version => '2.0' },
    { name => 'rex', version => '0.51.0' },
  );

  my @plist2 = (
    { name => 'vim',       version => '1.0' },
    { name => 'rex',       version => '0.52.0' },
    { name => 'libssh2-1', version => '0.32.1' },
  );

  my @expected = (
    {
      action  => 'updated',
      name    => 'rex',
      version => '0.52.0',
    },
    {
      action  => 'removed',
      name    => 'mc',
      version => '2.0',
    },
    {
      action  => 'installed',
      name    => 'libssh2-1',
      version => '0.32.1',
    },
  );

  my @mods = $pkg->diff_package_list( \@plist1, \@plist2 );

  cmp_deeply( \@mods, \@expected, 'expected package modifications' );
};

1;
