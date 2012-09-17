use strict;
use warnings;

use Test::More tests => 5;

use_ok 'Rex';
use_ok 'Rex::Commands';
use_ok 'Rex::Config';
use_ok 'Rex::Commands::Virtualization';

Rex::Commands::set(virtualization => "LibVirt");
ok(Rex::Config->get("virtualization") eq "LibVirt", "set virtualization handler");

