use strict;
use warnings;

use Test::More;
use Test::Output;
use Rex::Inventory::Proc;

if ( !-d '/proc' ) {
  plan skip_all => 'No procfs found';
}

if ( !-r '/proc' ) {
  plan skip_all => 'Procfs is not readable';
}

plan tests => 1;

stderr_like( sub { Rex::Inventory::Proc->new() }, qr{^$}, 'stderr is empty' );
