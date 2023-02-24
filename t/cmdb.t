#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 2;

use Cwd qw(realpath);
use File::Spec;
use Rex::CMDB;
use Rex::Commands;
use Rex::Commands::File;
use Test::Deep qw(cmp_deeply);

my $cmdb_type = 'YAML';
my $cmdb_path = realpath( File::Spec->join( 't', 'cmdb' ) );

foreach my $caching (qw(0 1)) {
  my $setting = $caching ? 'enabled' : 'disabled';

  my $server = 'foo';

  my $expected_all = {
    ntp                 => [qw(ntp1 ntp2)],
    newntp              => [qw(ntpdefaultfoo01 ntpdefaultfoo02)],
    dns                 => [qw(1.1.1.1 2.2.2.2)],
    'MyTest::foo::mode' => '0666',
    vhost               => {
      name     => 'foohost',
      doc_root => '/var/www',
    },
    name   => $server,
    vhost2 => {
      name     => 'vhost2foo',
      doc_root => '/var/www',
    },
    users => {
      root => {
        password => 'proot',
        id       => '0',
      },
      user02 => {
        password => 'puser02',
        id       => '600',
      },
      user01 => {
        password => 'puser01',
        id       => '500',
      },
    },
  };

  subtest "Caching ${setting}" => sub {
    plan tests => 5;

    Rex::Config->set_use_cache($caching);

    set(
      cmdb => {
        type => $cmdb_type,
        path => $cmdb_path,
      },
    );

    subtest 'getting item for server foo' => sub {
      my $ntp = get( cmdb( 'ntp', $server ) );
      cmp_deeply( $ntp, [qw(ntp1 ntp2)],
        'arrayref server item from default.yml' );

      my $name = get( cmdb( 'name', $server ) );
      is( $name, $server, 'scalar server item from foo.yml' );

      my $dns = get( cmdb( 'dns', $server ) );
      cmp_deeply( $dns, [qw(1.1.1.1 2.2.2.2)],
        'arrayref server item from env/default.yml' );

      my $vhost = get( cmdb( 'vhost', $server ) );
      cmp_deeply(
        $vhost,
        { name => 'foohost', doc_root => '/var/www', },
        'hashref server item from env/foo.yml'
      );
    };

    subtest 'getting item' => sub {
      my $ntp = get( cmdb('ntp') );
      cmp_deeply( $ntp, [qw(ntp1 ntp2)], 'arrayref item from default.yml' );

      my $dns = get( cmdb('dns') );
      cmp_deeply( $dns, [qw(1.1.1.1 2.2.2.2)],
        'arrayref item from env/default.yml' );
    };

    subtest 'getting server' => sub {
      my $all = get( cmdb( undef, $server ) );
      cmp_deeply( $all, $expected_all, 'combined CMDB for server foo' );
    };

    subtest 'CMDB variables in templates' => sub {
      Rex::Config->set_register_cmdb_template(1);

      my $content = 'Hello this is <%= $::name %>';

      is(
        template( \$content, __no_sys_info__ => 1 ),
        'Hello this is defaultname',
        'get keys from CMDB'
      );

      is(
        template( \$content, { name => 'baz', __no_sys_info__ => 1 } ),
        'Hello this is baz',
        'overwrite keys from CMDB'
      );
    };

    subtest 'CMDB merging strategy' => sub {
      set(
        cmdb => {
          type           => $cmdb_type,
          path           => $cmdb_path,
          merge_behavior => 'LEFT_PRECEDENT',
        },
      );

      my $foo_all = get( cmdb( undef, $server ) );
      $expected_all->{newntp} = [qw(ntpdefaultfoo01 ntpdefaultfoo02 ntp1 ntp2)];
      cmp_deeply( $foo_all, $expected_all, 'DeepMerge CMDB' );
    };
  };
}
