#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 3;
use Test::Warnings;
use Test::Output;
use Rex::Inventory::Proc;

$Rex::Logger::silent = 1;

stderr_like( sub { Rex::Inventory::Proc->new() }, qr{^$}, 'stderr is empty' );

my $cpu_count = scalar @{ Rex::Inventory::Proc->new()->get_cpus };

if ( -r '/proc/cpuinfo' ) {
  isnt( $cpu_count, 0, 'Found some CPUs' );
}
else {
  is( $cpu_count, 0, 'No CPUs found' );
}
