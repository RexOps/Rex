use strict;
use warnings;

use Test::More tests => 2;
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
