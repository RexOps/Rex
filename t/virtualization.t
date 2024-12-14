#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 4;
use Test::Warnings;

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
