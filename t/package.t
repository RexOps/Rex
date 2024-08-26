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

use Storable 'dclone';

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
  ## no critic (ProhibitDuplicateLiteral)

  plan tests => 4;

  my $rh_pkg = Rex::Pkg::Redhat->new;

  my @orig = (
    {
      'arch'    => 'x86_64',
      'version' => '5.14.0',
      'release' => '427.26.1.el9_4',
      'name'    => 'kernel',
      'epoch'   => '0',
    },
    {
      'version' => '5.14.0',
      'arch'    => 'x86_64',
      'name'    => 'kernel',
      'epoch'   => '0',
      'release' => '427.28.1.el9_4',
    },
    {
      'arch'    => 'x86_64',
      'version' => '5.14.0',
      'name'    => 'kernel',
      'epoch'   => '0',
      'release' => '427.31.1.el9_4',
    },
  );

  my @plist1   = @{ dclone( \@orig ) };
  my @plist2   = @{ dclone( \@orig ) };
  my @expected = ();

  my @mods = $rh_pkg->diff_package_list( \@plist1, \@plist2 );
  cmp_deeply( \@mods, \@expected,
    'expected package modifications when nothing changed' );

  @plist1 = @{ dclone( \@orig ) };
  pop @plist1;
  @plist2   = @{ dclone( \@orig ) };
  @expected = ( { %{ $orig[2] }, action => 'installed' } );

  @mods = $rh_pkg->diff_package_list( \@plist1, \@plist2 );
  cmp_deeply( \@mods, \@expected,
    'expected package modifications when new kernel release is installed' );

  @plist1 = @{ dclone( \@orig ) };
  pop @plist1;
  @plist2 = @{ dclone( \@orig ) };
  shift @plist2;
  @expected = ( { %{ $orig[2] }, action => 'updated' } );

  @mods = $rh_pkg->diff_package_list( \@plist1, \@plist2 );
  cmp_deeply( \@mods, \@expected,
    'expected package modifications when new kernel release is installed and an old one removed'
  );

  @plist1 = @{ dclone( \@orig ) };
  @plist2 = @{ dclone( \@orig ) };
  shift @plist2;
  @expected = ( { %{ $orig[0] }, action => 'removed' } );

  @mods = $rh_pkg->diff_package_list( \@plist1, \@plist2 );
  cmp_deeply( \@mods, \@expected,
    'expected package modifications when only a kernel release is removed' );

  ## use critic
};

1;
