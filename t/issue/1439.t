#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 3;
use Test::Warnings;

require Rex;

ok( !Rex::Config->get_autodie(), 'By default, autodie isn\'t enabled' );
Rex->import( -feature => 'autodie' );
ok( Rex::Config->get_autodie(), 'We can enable the autodie feature' );
