use strict;
use warnings;

use Test::More tests => 3;
use File::Temp qw(tempfile);
use Rex::Commands::MD5;

# the name of the temporary test file is matching the output structure
# of the md5 command on purpose, see #1429 for details

my ( $fh, $test_file ) = tempfile(
  SUFFIX => ' = 11111111111111111111111111111111',
  UNLINK => 1,
);
print $fh "\x00";
close($fh);

my $expected_checksum = '93b885adfe0da089cdf634904fd59f71';

is( md5($test_file), $expected_checksum, 'MD5 checksum OK' );

# test internal interfaces

is( Rex::Commands::MD5::_digest_md5($test_file),
  $expected_checksum, 'MD5 checksum OK via Digest::MD5' );

SKIP: {
  my $checksum_via_binary = Rex::Commands::MD5::_binary_md5($test_file);

  skip 'No MD5 binary seems to be available', 1
    if !defined $checksum_via_binary;

  is( $checksum_via_binary, $expected_checksum, 'MD5 checksum OK via binary' );
}
