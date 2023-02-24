#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 2;

require Rex;

ok( !Rex::Config->get_autodie(), 'By default, autodie isn\'t enabled' );
Rex->import( -feature => 'autodie' );
ok( Rex::Config->get_autodie(), 'We can enable the autodie feature' );
