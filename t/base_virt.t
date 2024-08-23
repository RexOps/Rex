#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 3;
use Test::Warnings;

use Rex::Virtualization;

my $vm_obj = Rex::Virtualization->create("VBox");
ok( ref($vm_obj) eq "Rex::Virtualization::VBox",
  "created vm object with param" );

Rex::Config->set( virtualization => "LibVirt" );
$vm_obj = Rex::Virtualization->create();
ok( ref($vm_obj) eq "Rex::Virtualization::LibVirt",
  "created vm object with config" );
