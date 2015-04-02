use strict;
use warnings;

use Test::More tests => 4;
use Data::Dumper;

use_ok 'Rex::CMDB';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::File';

Rex::Commands->import;
Rex::CMDB->import;

set(
  cmdb => {
    type => "Rex::CMDB::YAML::DeepMerge",
    path => "t/cmdb",
  }
);

my $foo_all = get( cmdb( undef, "foo" ) );

is_deeply(
  $foo_all,
  {
    'ntp'    => [ 'ntp1',            'ntp2' ],
    'newntp' => [ 'ntpdefaultfoo01', 'ntpdefaultfoo02', 'ntp1', 'ntp2' ],
    'dns'    => [ '1.1.1.1',         '2.2.2.2' ],
    'vhost' => {
      'name'     => 'foohost',
      'doc_root' => '/var/www'
    },
    'name'   => 'foo',
    'vhost2' => {
      'name'     => 'vhost2foo',
      'doc_root' => '/var/www'
    },
    'users' => {
      'root' => {
        'password' => 'proot',
        'id'       => '0'
      },
      'user02' => {
        'password' => 'puser02',
        'id'       => '600'
      },
      'user01' => {
        'password' => 'puser01',
        'id'       => '500'
      }
    }
  },
  "DeepMerge CMDB"
);


