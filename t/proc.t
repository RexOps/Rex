use strict;
use warnings;

use Test::More;
use Test::Output;
use Rex::Inventory::Proc;

if ( -d '/proc' ) {
  plan tests => 1;
}
else {
  plan skip_all => 'No procfs found';
}

stderr_like( sub { Rex::Inventory::Proc->new() }, qr{^$}, 'stderr is empty' );
