#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 4;
use Test::Warnings;
use Test::Deep;
use Test::Exception;

use Rex::Pkg::Test;
use Rex::Pkg::Redhat;

my $pkg = Rex::Pkg::Test->new;

subtest 'package list diffs' => sub {
  plan tests => 1;

  ## no critic (ProhibitDuplicateLiteral)

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

  ## use critic

  my @mods = $pkg->diff_package_list( \@plist1, \@plist2 );

  cmp_deeply( \@mods, \@expected, 'expected package modifications' );
};

subtest 'local package installation' => sub {
  plan tests => 1;

  lives_ok { $pkg->update('test_package') }, 'update test package';
};

subtest 'redhat package list diffs' => sub {
  plan tests => 1;

  my $rh_pkg = Rex::Pkg::Redhat->new;

  ## no critic (ProhibitDuplicateLiteral)

  my @before = (
    {
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'lzo',
      release => '8.el7',
      version => '2.06',
    },
    {
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'postgresql-server',
      release => '1.el7',
      version => '9.2.18',
    },
    {
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'kernel',
      release => '427.26.1.el9_4',
      version => '5.14.0',
    },
  );

  my @after = (
    {
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'postgresql-server',
      release => '1.el7',
      version => '9.2.19',
    },
    {
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'kernel',
      release => '427.28.1.el9_4',
      version => '5.14.0',
    },
    {
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'kernel',
      release => '427.26.1.el9_4',
      version => '5.14.0',
    },
  );

  my @expected = (
    {
      action  => 'updated',
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'postgresql-server',
      release => '1.el7',
      version => '9.2.19',
    },
    {
      action  => 'installed',
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'kernel',
      release => '427.28.1.el9_4',
      version => '5.14.0',
    },
    {
      action  => 'removed',
      arch    => 'x86_64',
      epoch   => '0',
      name    => 'lzo',
      release => '8.el7',
      version => '2.06',
    },
  );

  ## use critic

  my @mods = $rh_pkg->diff_package_list( \@before, \@after );

  cmp_bag( \@mods, \@expected,
    'expected package modifications on Red Hat compatible distros' );
};

1;
