use strict;
use warnings;

use Test::More tests => 3;

use Rex::Commands;

Rex::Commands::set( virtualization => "LibVirt" );
is( Rex::Config->get("virtualization"),
  "LibVirt", "set virtualization handler" );

Rex::Commands::set(
  virtualization => { "type" => "LibVirt", "connect" => "qemu:///system", } );
is( Rex::Config->get("virtualization")->{type},
  "LibVirt", "Virtualization type with connection URI" );
is( Rex::Config->get("virtualization")->{connect},
  "qemu:///system", "Virtualization URI with connection URI" );
