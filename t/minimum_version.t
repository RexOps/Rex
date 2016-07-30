use strict;
use warnings;

use Test::MinimumVersion::Fast;
all_minimum_version_ok( '5.10.0', { paths => [qw/bin lib t/] } );
