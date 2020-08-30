use strict;
use warnings;

use Test::More tests => 3;
use Rex::Commands::MD5;

my $test_file = Rex::Helper::File::Spec->catfile( 't', 'md5test.bin' );

is( md5($test_file), '93b885adfe0da089cdf634904fd59f71', 'MD5 checksum OK' );

# test internal interfaces

is(
  Rex::Commands::MD5::_digest_md5($test_file),
  '93b885adfe0da089cdf634904fd59f71',
  'MD5 checksum OK via Digest::MD5'
);

SKIP: {
  skip 'No MD5 binary seems to be available', 1
    if !defined Rex::Commands::MD5::_binary_md5($test_file);

  is(
    Rex::Commands::MD5::_binary_md5($test_file),
    '93b885adfe0da089cdf634904fd59f71',
    'MD5 checksum OK via binary'
  );
}
