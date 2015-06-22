use strict;
use warnings;

use Test::More tests => 1;
use Rex::Commands::MD5;

my $test_file = Rex::Helper::File::Spec->catfile( 't', 'md5test.bin' );

is( md5($test_file), '93b885adfe0da089cdf634904fd59f71', 'MD5 checksum OK' );
