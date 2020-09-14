use strict;
use warnings;

use Test::More tests => 4;
use File::Temp qw(tempfile);
use Rex::Commands::MD5;

my $test_file = Rex::Helper::File::Spec->catfile( 't', 'md5test.bin' );

my ( $fh, $strangely_named_file ) = tempfile(
  "XXXXX",
  SUFFIX => " = 11111111111111111111111111111111",
  TMPDIR => 1
);
print $fh "\x00";
close($fh);

is( md5($test_file), '93b885adfe0da089cdf634904fd59f71', 'MD5 checksum OK' );

# test internal interfaces

is(
  Rex::Commands::MD5::_digest_md5($test_file),
  '93b885adfe0da089cdf634904fd59f71',
  'MD5 checksum OK via Digest::MD5'
);

SKIP: {
  skip 'No MD5 binary seems to be available', 2
    if !defined Rex::Commands::MD5::_binary_md5($test_file);

  is(
    Rex::Commands::MD5::_binary_md5($test_file),
    '93b885adfe0da089cdf634904fd59f71',
    'MD5 checksum OK via binary'
  );

  is(
    Rex::Commands::MD5::_binary_md5($strangely_named_file),
    '93b885adfe0da089cdf634904fd59f71',
    'MD5 checksum OK via binary for strangely named file'
  );
}
