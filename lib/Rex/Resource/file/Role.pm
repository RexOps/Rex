package Rex::Resource::file::Role;

use strict;
use warnings;

# VERSION

use Moose::Role;

with qw(Rex::Resource::Role::Ensureable);

has ensure_options => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { [qw/present absent directory/] },
);

requires qw(directory);

1;
