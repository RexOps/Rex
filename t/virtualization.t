use strict;
use warnings;

use Test::More tests => 7;

use_ok 'Rex';
use_ok 'Rex::Commands';
use_ok 'Rex::Config';
use_ok 'Rex::Commands::Virtualization';

Rex::Commands::set(virtualization => "LibVirt");
ok(Rex::Config->get("virtualization") eq "LibVirt", "set virtualization handler");

Rex::Commands::set(
    virtualization => { "type" => "LibVirt", "connect" => "qemu:///system", } );
is( Rex::Config->get("virtualization")->{type},
    "LibVirt", "Virtualization type with connection URI" );
is( Rex::Config->get("virtualization")->{connect},
    "qemu:///system", "Virtualization URI with connection URI" );
